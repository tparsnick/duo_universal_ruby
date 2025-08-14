require 'net/http'      # for Net::HTTP, Net::HTTP::Post, URI HTTP requests
require 'uri'           # for URI and URI.parse
require 'json'          # for JSON.parse
require 'jwt'           # for JWT.encode / JWT.decode (gem)
require 'securerandom'  # for SecureRandom in generate_rand_alphanumeric
require 'openssl'       # for OpenSSL::SSL constants and verify modes

module DuoUniversalRuby
  class Client
    def initialize(client_id:, client_secret:, api_host:, redirect_uri:, duo_certs: DEFAULT_CA_CERT_PATH,
                   use_duo_code_attribute: true, http_proxy: nil, exp_seconds: FIVE_MINUTES_IN_SECONDS)
      # Initializes instance of Client class

      # Arguments:

      # client_id                -- Client ID for the application in Duo
      # client_secret            -- Client secret for the application in Duo
      # host                     -- Duo api host
      # redirect_uri             -- Uri to redirect to after a successful auth
      # duo_certs                -- (Optional: default is ca_certs.pem) Provide custom CA certs
      # use_duo_code_attribute   -- (Optional: default true) Flag to use `duo_code` instead of `code` for returned authorization parameter
      # http_proxy               -- (Optional) HTTP proxy to tunnel requests through
      # exp_seconds              -- (Optional) The number of seconds used for JWT expiry. Must be be at most 5 minutes.

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
      # Random value passed initially in the OAUTH_V1_AUTHORIZE_ENDPOINT and verfied throughout interactions.
      # It is up to the client to verify that it is the same value as a security measure.
      # This value specifically protects against CSRF attacks (see RFC 6749)
      generate_rand_alphanumeric(STATE_LENGTH)
    end

    def health_check
      # Checks whether Duo is available.

      # Returns:
      # {'response': {'timestamp': <int:unix timestamp>}, 'stat': 'OK'}

      # Raises:
      # DuoException on error for invalid credentials
      # or problem connecting to Duo

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

    def create_auth_url(username:, state:, nonce: nil)
      # Generate uri to Duo's prompt

      # Arguments:
      # username        -- username trying to authenticate with Duo
      # state           -- Randomly generated character string of at least 16
      #                    and at most 1024 characters returned to the integration by Duo after 2FA
      # nonce           -- (Optional) Randomly generated character string of at least 16
      #                    and at most 1024 characters used as the nonce for the underlying OIDC flow

      # Returns:
      # Authorization uri to redirect to for the Duo prompt

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

    def exchange_authorization_code_for_2fa_result(duo_code:, username:, nonce: nil)
      # Exchange the duo_code for a token with Duo to determine
      # if the auth was successful.

      # Arguments:
      # duoCode         -- Authentication session transaction id
      #                    returned by Duo
      # username        -- Name of the user authenticating with Duo
      # nonce           -- (Optional) Random 36B string used to associate
      #                    a session with an ID token

      # Return:
      # A token with meta-data about the auth

      # Raises:
      # DuoException on error for invalid duo_codes, invalid credentials,
      # or problems connecting to Duo
     
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

      # ID Token validation
      # https://openid.net/specs/openid-connect-core-1_0.html#IDTokenValidation
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
