require 'uri'
require 'net/http'
require 'json'
require 'jwt'
require 'securerandom'
require 'openssl'

module DuoUniversal
  CLIENT_ID_LENGTH = 20
  CLIENT_SECRET_LENGTH = 40
  JTI_LENGTH = 36
  MINIMUM_STATE_LENGTH = 16
  MAXIMUM_STATE_LENGTH = 1024
  STATE_LENGTH = 36
  SUCCESS_STATUS_CODE = 200
  FIVE_MINUTES_IN_SECONDS = 300
  LEEWAY = 60

  ERR_USERNAME = 'The username is invalid.'
  ERR_NONCE = 'The nonce is invalid.'
  ERR_CLIENT_ID = 'The Duo client id is invalid.'
  ERR_CLIENT_SECRET = 'The Duo client secret is invalid.'
  ERR_API_HOST = 'The Duo api host is invalid'
  ERR_REDIRECT_URI = 'No redirect uri'
  ERR_CODE = 'Missing authorization code'
  ERR_GENERATE_LEN = 'Length needs to be at least 16'
  ERR_STATE_LEN = "State must be at least #{MINIMUM_STATE_LENGTH} characters long and no longer than #{MAXIMUM_STATE_LENGTH} characters"
  ERR_NONCE_LEN = "Nonce must be at least #{MINIMUM_STATE_LENGTH} characters long and no longer than #{MAXIMUM_STATE_LENGTH} characters"
  ERR_EXP_SECONDS_TOO_LONG = 'Client may not be configured for a JWT expiry longer than five minutes.'
  ERR_EXP_SECONDS_TOO_SHORT = 'Invalid JWT expiry duration.'

  API_HOST_URI_FORMAT = 'https://%s'
  OAUTH_V1_HEALTH_CHECK_ENDPOINT = 'https://%s/oauth/v1/health_check'
  OAUTH_V1_AUTHORIZE_ENDPOINT = 'https://%s/oauth/v1/authorize'
  OAUTH_V1_TOKEN_ENDPOINT = 'https://%s/oauth/v1/token'
  DEFAULT_CA_CERT_PATH = File.join(__dir__, 'ca_certs.pem')

  CLIENT_ASSERT_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

  class Error < StandardError; end

  class Client
    def initialize(client_id, client_secret, api_host, redirect_uri, duo_certs: DEFAULT_CA_CERT_PATH,
                   use_duo_code_attribute: true, http_proxy: nil, exp_seconds: FIVE_MINUTES_IN_SECONDS)
      validate_init_config(client_id, client_secret, api_host, redirect_uri, exp_seconds)

      @client_id = client_id
      @client_secret = client_secret
      @api_host = api_host
      @redirect_uri = redirect_uri
      @use_duo_code_attribute = use_duo_code_attribute
      @duo_certs = duo_certs == "DISABLE" ? false : (duo_certs || DEFAULT_CA_CERT_PATH)
      @http_proxy = http_proxy
      @exp_seconds = exp_seconds
    end

    def clamped_expiry_duration
      [[FIVE_MINUTES_IN_SECONDS, @exp_seconds].min, 1].max
    end

    def generate_state
      generate_rand_alphanumeric(STATE_LENGTH)
    end

    def health_check
      endpoint = format(OAUTH_V1_HEALTH_CHECK_ENDPOINT, @api_host)
      payload = create_jwt_payload(endpoint)
      body = {
        'client_assertion' => JWT.encode(payload, @client_secret, 'HS512'),
        'client_id' => @client_id
      }

      response = post_form(endpoint, body)
      result = JSON.parse(response.body)
      raise Error, result unless result['stat'] == 'OK'
      result
    rescue => e
      raise Error, e.message
    end

    def create_auth_url(username, state, nonce = nil)
      raise Error, ERR_STATE_LEN unless state && state.length.between?(MINIMUM_STATE_LENGTH, MAXIMUM_STATE_LENGTH)
      raise Error, ERR_USERNAME unless username
      raise Error, ERR_NONCE_LEN if nonce && !nonce.length.between?(MINIMUM_STATE_LENGTH, MAXIMUM_STATE_LENGTH)

      endpoint = format(OAUTH_V1_AUTHORIZE_ENDPOINT, @api_host)
      jwt_payload = {
        'scope' => 'openid',
        'redirect_uri' => @redirect_uri,
        'client_id' => @client_id,
        'iss' => @client_id,
        'aud' => format(API_HOST_URI_FORMAT, @api_host),
        'exp' => Time.now.to_i + clamped_expiry_duration,
        'state' => state,
        'response_type' => 'code',
        'duo_uname' => username,
        'use_duo_code_attribute' => @use_duo_code_attribute
      }
      request_jwt = JWT.encode(jwt_payload, @client_secret, 'HS512')

      params = {
        'response_type' => 'code',
        'client_id' => @client_id,
        'request' => request_jwt
      }
      params['nonce'] = nonce if nonce

      uri = URI(endpoint)
      uri.query = URI.encode_www_form(params)
      uri.to_s
    end

    def exchange_authorization_code_for_2fa_result(duo_code, username, nonce = nil)
      raise Error, ERR_CODE unless duo_code

      endpoint = format(OAUTH_V1_TOKEN_ENDPOINT, @api_host)
      payload = create_jwt_payload(endpoint)
      request_data = {
        'grant_type' => 'authorization_code',
        'code' => duo_code,
        'redirect_uri' => @redirect_uri,
        'client_id' => @client_id,
        'client_assertion_type' => CLIENT_ASSERT_TYPE,
        'client_assertion' => JWT.encode(payload, @client_secret, 'HS512')
      }

      user_agent = "duo_universal_ruby/1.0 ruby/#{RUBY_VERSION} #{RUBY_PLATFORM}"
      headers = { 'User-Agent' => user_agent }

      response = post_form(endpoint, request_data, headers)
      raise Error, JSON.parse(response.body) unless response.code.to_i == SUCCESS_STATUS_CODE

      id_token = JSON.parse(response.body)['id_token']
      decoded, = JWT.decode(
        id_token,
        @client_secret,
        true,
        {
          aud: @client_id,
          iss: format(OAUTH_V1_TOKEN_ENDPOINT, @api_host),
          leeway: LEEWAY,
          algorithm: 'HS512',
          verify_iss: true,
          verify_aud: true,
          verify_iat: true,
          require: ['exp', 'iat']
        }
      )

      raise Error, ERR_USERNAME unless decoded['preferred_username'] == username
      raise Error, ERR_NONCE if nonce && decoded['nonce'] != nonce

      decoded
    rescue => e
      raise Error, e.message
    end

    private

    def generate_rand_alphanumeric(length)
      raise ArgumentError, ERR_GENERATE_LEN if length < [MINIMUM_STATE_LENGTH, JTI_LENGTH].min
      charset = [('A'..'Z'), ('a'..'z'), ('0'..'9')].map(&:to_a).flatten
      Array.new(length) { charset.sample(random: SecureRandom) }.join
    end

    def validate_init_config(client_id, client_secret, api_host, redirect_uri, exp_seconds)
      raise Error, ERR_CLIENT_ID unless client_id && client_id.length == CLIENT_ID_LENGTH
      raise Error, ERR_CLIENT_SECRET unless client_secret && client_secret.length == CLIENT_SECRET_LENGTH
      raise Error, ERR_API_HOST unless api_host
      raise Error, ERR_REDIRECT_URI unless redirect_uri
      raise Error, ERR_EXP_SECONDS_TOO_LONG if exp_seconds > FIVE_MINUTES_IN_SECONDS
      raise Error, ERR_EXP_SECONDS_TOO_SHORT if exp_seconds < 0
    end

    def create_jwt_payload(aud)
      {
        'iss' => @client_id,
        'sub' => @client_id,
        'aud' => aud,
        'exp' => Time.now.to_i + clamped_expiry_duration,
        'jti' => generate_rand_alphanumeric(JTI_LENGTH)
      }
    end

    def post_form(url, form_data, headers = {})
      uri = URI.parse(url)
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(form_data)
      headers.each { |k, v| req[k] = v }

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      if @duo_certs != false
        http.ca_file = @duo_certs
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      else
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      http.request(req)
    end
  end
end
