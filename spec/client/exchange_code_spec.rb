require "spec_helper"

RSpec.describe DuoUniversalRuby::Client do
  include_context "duo_client"

  describe "#exchange_authorization_code_for_2fa_result" do
    let(:duo_code) { "xyz123" }
    let(:username) { "alice" }
    let(:token_base_url) { format(DuoUniversalRuby::OAUTH_V1_TOKEN_ENDPOINT, api_host) }
    let(:id_token) do
      payload = {
        preferred_username: username,
        nonce: nil,
        exp: Time.now.to_i + 300,
        iat: Time.now.to_i,
        iss: token_base_url,
        aud: client_id
      }
      JWT.encode(payload, client_secret, "HS512")
    end

    it "returns decoded ID token when Duo responds with success" do
      stub_request(:post, token_base_url)
        .to_return(
          status: 200,
          body: { id_token: id_token }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      decoded = client.exchange_authorization_code_for_2fa_result(
        duo_code: duo_code,
        username: username
      )
      expect(decoded["preferred_username"]).to eq(username)
    end

    it "raises error if username does not match" do
      wrong_token = JWT.encode(
              { 
                preferred_username: "wrong",
                exp: Time.now.to_i + 300,
                iat: Time.now.to_i,
                iss: token_base_url,
                aud: client_id
              },
              client_secret, "HS512"
            )

      stub_request(:post, token_base_url)
        .to_return(
          status: 200,
          body: { id_token: wrong_token }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect {
        client.exchange_authorization_code_for_2fa_result(
          duo_code: duo_code,
          username: username
        )
      }.to raise_error(DuoUniversalRuby::Error, /username/i)
    end
  end
end
