require 'rails_helper'

RSpec.describe ContentSafety::OpenaiClient, type: :service do
  let(:api_key) { 'test_api_key_12345' }
  let(:client) { described_class.new }
  let(:test_text) { 'This is test content' }

  before do
    ENV['OPENAI_API_KEY'] = api_key
  end

  after do
    ENV.delete('OPENAI_API_KEY')
  end

  describe '#initialize' do
    context 'when API key is present' do
      it 'initializes successfully' do
        expect { client }.not_to raise_error
      end
    end

    context 'when API key is missing' do
      before { ENV.delete('OPENAI_API_KEY') }

      it 'raises MissingApiKeyError' do
        expect { client }.to raise_error(
          ContentSafety::OpenaiClient::MissingApiKeyError,
          'OPENAI_API_KEY environment variable is required'
        )
      end
    end

    context 'when API key is empty string' do
      before { ENV['OPENAI_API_KEY'] = '' }

      it 'raises MissingApiKeyError' do
        expect { client }.to raise_error(
          ContentSafety::OpenaiClient::MissingApiKeyError
        )
      end
    end
  end

  describe '#screen' do
    let(:api_url) { 'https://api.openai.com/v1/moderations' }

    context 'when content is flagged' do
      let(:flagged_response) do
        {
          id: 'modr-test123',
          model: 'omni-moderation-latest',
          results: [
            {
              flagged: true,
              categories: {
                violence: true,
                harassment: false
              },
              category_scores: {
                violence: 0.85,
                harassment: 0.01
              }
            }
          ]
        }.to_json
      end

      before do
        stub_request(:post, api_url)
          .with(
            body: {
              model: 'omni-moderation-latest',
              input: test_text
            }.to_json,
            headers: {
              'Authorization' => "Bearer #{api_key}",
              'Content-Type' => 'application/json'
            }
          )
          .to_return(status: 200, body: flagged_response, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns flagged: true' do
        result = client.screen(text: test_text)
        expect(result[:flagged]).to be true
      end
    end

    context 'when content is not flagged' do
      let(:safe_response) do
        {
          id: 'modr-test456',
          model: 'omni-moderation-latest',
          results: [
            {
              flagged: false,
              categories: {
                violence: false,
                harassment: false
              },
              category_scores: {
                violence: 0.01,
                harassment: 0.001
              }
            }
          ]
        }.to_json
      end

      before do
        stub_request(:post, api_url)
          .to_return(status: 200, body: safe_response, headers: { 'Content-Type' => 'application/json' })
      end

      it 'returns flagged: false' do
        result = client.screen(text: test_text)
        expect(result[:flagged]).to be false
      end
    end

    context 'when API returns an error' do
      before do
        stub_request(:post, api_url)
          .to_return(status: 500, body: 'Internal Server Error')
      end

      it 'raises Error' do
        expect { client.screen(text: test_text) }.to raise_error(
          ContentSafety::OpenaiClient::Error,
          /Failed to screen content/
        )
      end
    end

    context 'when API returns invalid JSON' do
      before do
        stub_request(:post, api_url)
          .to_return(status: 200, body: 'invalid json')
      end

      it 'raises Error' do
        expect { client.screen(text: test_text) }.to raise_error(
          ContentSafety::OpenaiClient::Error
        )
      end
    end

    context 'when API returns unexpected format' do
      let(:bad_response) do
        { no_results: 'here' }.to_json
      end

      before do
        stub_request(:post, api_url)
          .to_return(status: 200, body: bad_response, headers: { 'Content-Type' => 'application/json' })
      end

      it 'raises Error' do
        expect { client.screen(text: test_text) }.to raise_error(
          ContentSafety::OpenaiClient::Error,
          /Unexpected API response format/
        )
      end
    end
  end
end
