require "spec_helper"

RSpec.describe DuoUniversalRuby::Client do
  include_context "duo_client"

  describe "#health_check" do
    let(:health_check_base_url) { format(DuoUniversalRuby::OAUTH_V1_HEALTH_CHECK_ENDPOINT, api_host) }

    it "returns OK when Duo responds with stat OK" do
      stub_request(:post, health_check_base_url)
        .to_return(
          status: 200,
          body: { stat: "OK", response: { timestamp: Time.now.to_i } }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      result = client.health_check
      expect(result["stat"]).to eq("OK")
      expect(result["response"]).to have_key("timestamp")
    end

    it "raises error when Duo stat is not OK" do
      stub_request(:post, health_check_base_url)
        .to_return(
          status: 200,
          body: { stat: "FAIL" }.to_json,
          headers: { "Content-Type" => "application/json" }
        )

      expect { client.health_check }.to raise_error(DuoUniversalRuby::Error)
    end
  end
end
