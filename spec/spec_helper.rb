require 'rspec'
require 'webmock/rspec'
require 'jwt'
require 'duo_universal_ruby'
require_relative 'support/client_fixtures'

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.include_context "duo_client", include_shared: true
end
