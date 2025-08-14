RSpec.shared_context "duo_client" do
  let(:client_id) { "DIXXXXXXXXXXXXXXXXXX" }
  let(:client_secret) { "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef" }
  let(:api_host) { "api-123456.duosecurity.com" }
  let(:redirect_uri) { "https://example.com/callback" }
  let(:exp_seconds) { 300 }

  let(:client) do
    DuoUniversalRuby::Client.new(
      client_id: client_id,
      client_secret: client_secret,
      api_host: api_host,
      redirect_uri: redirect_uri,
      exp_seconds: exp_seconds
    )
  end
end
