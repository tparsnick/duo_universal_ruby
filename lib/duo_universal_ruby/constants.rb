# frozen_string_literal: true

module DuoUniversalRuby
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
end
