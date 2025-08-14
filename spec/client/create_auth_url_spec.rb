require "spec_helper"

RSpec.describe DuoUniversalRuby::Client do
  include_context "duo_client"

  describe "#create_auth_url" do
    let(:state) { "A" * DuoUniversalRuby::STATE_LENGTH }
    let(:username) { "bob" }
    let(:auth_base_url) { format(DuoUniversalRuby::OAUTH_V1_AUTHORIZE_ENDPOINT, api_host) }

    it "returns a valid Duo auth URL" do
      url = client.create_auth_url(username: username, state: state)
      expect(url).to include(auth_base_url)
      expect(url).to include("client_id=#{client_id}")
      expect(url).to include("response_type=code")
    end

    it "raises error for short state" do
      expect {
        client.create_auth_url(username: username, state: "short")
      }.to raise_error(DuoUniversalRuby::Error)
    end
  end
end
