require 'webmock/rspec'

# Disable all external HTTP connections by default
WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  # Stub OpenAI Moderation API globally
  # This prevents WebMock warnings when the API is called during tests
  config.before(:each) do
    stub_request(:post, "https://api.openai.com/v1/moderations")
      .to_return(
        status: 200,
        body: {
          id: "modr-test",
          model: "omni-moderation-latest",
          results: [
            {
              flagged: false,
              categories: {
                sexual: false,
                hate: false,
                harassment: false,
                "self-harm": false,
                "sexual/minors": false,
                "hate/threatening": false,
                "violence/graphic": false,
                "self-harm/intent": false,
                "self-harm/instructions": false,
                "harassment/threatening": false,
                violence: false
              },
              category_scores: {
                sexual: 0.0001,
                hate: 0.0001,
                harassment: 0.0001,
                "self-harm": 0.0001,
                "sexual/minors": 0.0001,
                "hate/threatening": 0.0001,
                "violence/graphic": 0.0001,
                "self-harm/intent": 0.0001,
                "self-harm/instructions": 0.0001,
                "harassment/threatening": 0.0001,
                violence: 0.0001
              }
            }
          ]
        }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
  end
end
