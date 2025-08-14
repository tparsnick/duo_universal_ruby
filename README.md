# DuoUniversalRuby

## A Ruby implementation of the Duo WebSDKv4 with Universal Prompt
- https://duo.com/docs/duoweb
- https://duo.com/docs/oauthapi

https://github.com/duosecurity/duo_universal_python was used as a guide.

## Installation

Install the gem and add to the application's Gemfile by executing:

    $ bundle add duo_universal_ruby

If bundler is not being used to manage dependencies, install the gem by executing:

    $ gem install duo_universal_ruby

## Usage

```ruby
client = DuoUniversalRails::Client.new(
            client_id: DUO_CLIENT_ID,
            client_secret: DUO_CLIENT_SECRET,
            api_host: DUO_HOST,
            redirect_uri: DUO_REDIRECT_URI
            )
    # Initializes instance of Client class

    # Arguments:
    # client_id                -- Client ID for the application in Duo
    # client_secret            -- Client secret for the application in Duo
    # host                     -- Duo api host
    # redirect_uri             -- Uri to redirect to after a successful auth

client.health_check
    # Checks whether Duo is available.
    # POST /oauth/v1/health_check

    # Returns:
    # {'response': {'timestamp': <int:unix timestamp>}, 'stat': 'OK'}

    # Raises:
    # DuoException on error for invalid credentials
    # or problem connecting to Duo

state = client.generate_state
    # Random value that is checked after interactions to protect against CSRF attacks
   
client.create_auth_url(username, state)
    # Generate uri to Duo's prompt
    # GET /oauth/v1/authorize

    # Arguments:
    # username        -- username trying to authenticate with Duo
    # state           -- Randomly generated character string of at least 16
    #                    and at most 1024 characters returned to the integration by Duo after 2FA

    # Returns:
    # Authorization uri to redirect to for the Duo prompt

    # After a successful Duo login, Duo redirect the user to the redirect_uri, e.g. /duo_callback with a duoCode and state

decoded_token = client.exchange_authorization_code_for_2fa_result(duoCode, username)
      # Exchange the duo_code for a token with Duo to determine
      # if the auth was successful.

      # POST /oauth/v1/token

      # Arguments:
      # duoCode         -- Authentication session transaction id
      #                    returned by Duo
      # username        -- Name of the user authenticating with Duo

      # Return:
      # A token with meta-data about the auth

      # Raises:
      # DuoException on error for invalid duo_codes, invalid credentials,
      # or problems connecting to Duo

```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Tests

Run `bundle exec rspec`  or `rspec spec` to run the tests.

These RSpec tests do not requre a real working Duo host.  The suite uses WebMock to stub HTTP calls.

## Demos
- https://github.com/tparsnick/duo_universal_rails_demo
- https://github.com/tparsnick/duo_universal_sinatra_demo

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/tparsnick/duo_universal_ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
