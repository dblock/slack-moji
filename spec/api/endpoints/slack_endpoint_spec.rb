require 'spec_helper'

describe Api::Endpoints::SlackEndpoint do
  include Api::Test::EndpointTest

  context 'with a SLACK_VERIFICATION_TOKEN' do
    let(:token) { 'slack-verification-token' }
    let(:team) { Fabricate(:team) }
    before do
      ENV['SLACK_VERIFICATION_TOKEN'] = token
    end
    context 'slash commands' do
      let(:user) { Fabricate(:user, team: team) }
      it 'returns an error with a non-matching verification token' do
        post '/api/slack/command',
             command: '/moji',
             text: 'clubs',
             channel_id: 'C1',
             user_id: 'user_id',
             team_id: 'team_id',
             token: 'invalid-token'
        expect(last_response.status).to eq 401
        response = JSON.parse(last_response.body)
        expect(response['error']).to eq 'Message token is not coming from Slack.'
      end
    end
    after do
      ENV.delete('SLACK_VERIFICATION_TOKEN')
    end
  end
end
