require 'spec_helper'

describe Api::Endpoints::SlackEndpoint do
  include Api::Test::EndpointTest

  context 'with a SLACK_VERIFICATION_TOKEN' do
    let(:token) { 'slack-verification-token' }
    let(:team) { Fabricate(:team) }
    let(:user) { Fabricate(:user, team: team) }
    before do
      ENV['SLACK_VERIFICATION_TOKEN'] = token
    end
    context 'slash commands' do
      it 'returns an error with a non-matching verification token' do
        post '/api/slack/command',
             command: '/moji',
             text: 'me',
             channel_id: 'C1',
             channel_name: 'channel',
             user_id: 'user_id',
             team_id: 'team_id',
             token: 'invalid-token'
        expect(last_response.status).to eq 401
        response = JSON.parse(last_response.body)
        expect(response['error']).to eq 'Message token is not coming from Slack.'
      end
      it 'generates a link to authorize the user with moji' do
        post '/api/slack/command',
             command: '/moji',
             text: 'me',
             channel_id: 'C1',
             channel_name: 'channel',
             user_id: user.user_id,
             team_id: user.team.team_id,
             token: token
        expect(last_response.status).to eq 201
        response = JSON.parse(last_response.body)
        expect(response).to eq(
          'text' => 'Please allow more emoji in your profile.',
          'attachments' => [
            'fallback' => "https://slack.com/oauth/authorize?scope=users.profile:write&client_id=&redirect_uri=/authorize&state=#{user.id}",
            'actions' => [
              'type' => 'button',
              'text' => 'Allow Moji',
              'url' => "https://slack.com/oauth/authorize?scope=users.profile:write&client_id=&redirect_uri=/authorize&state=#{user.id}"
            ]
          ],
          'user' => user.user_id,
          'channel' => 'C1'
        )
      end
      context 'with a user authorized with moji' do
        before do
          user.update_attributes!(access_token: 'slack-access-token')
        end
        it 'generates user options' do
          post '/api/slack/command',
               command: '/moji',
               text: 'me',
               channel_id: 'C1',
               channel_name: 'channel',
               user_id: user.user_id,
               team_id: user.team.team_id,
               token: token
          expect(last_response.status).to eq 201
          expect(last_response.body).to eq(
            user.to_slack_emoji_question.merge(
              user: user.user_id, channel: 'C1'
            ).to_json
          )
        end
      end
    end
    context 'interactive buttons' do
      context 'emoji-count' do
        it 'sets no emoji' do
          expect_any_instance_of(User).to receive(:emoji!)
          post '/api/slack/action', payload: {
            actions: [{ name: 'emoji-count', value: 0 }],
            channel: { id: 'C1', name: 'moji' },
            user: { id: user.user_id },
            team: { id: team.team_id },
            token: token,
            callback_id: 'emoji-count'
          }.to_json
          expect(last_response.status).to eq 201
          expect(user.reload.emoji_count).to eq 0
          expect(last_response.body).to eq(
            user.to_slack_emoji_question('Got it, no emoji.').to_json
          )
        end
        it 'sets emoji' do
          expect_any_instance_of(User).to receive(:emoji!)
          post '/api/slack/action', payload: {
            actions: [{ name: 'emoji-count', value: 1 }],
            channel: { id: 'C1', name: 'moji' },
            user: { id: user.user_id },
            team: { id: team.team_id },
            token: token,
            callback_id: 'emoji-count'
          }.to_json
          expect(last_response.status).to eq 201
          expect(user.reload.emoji_count).to eq 1
          expect(last_response.body).to eq(
            user.to_slack_emoji_question('Got it, 1 emoji.').to_json
          )
        end
      end
      context 'emoji-text' do
        it 'parses and converts emoji' do
          expect_any_instance_of(Slack::Web::Client).to receive(:reactions_add).exactly(2).times
          post '/api/slack/action', payload: {
            type: 'message_action',
            user: { id: user.user_id },
            team: { id: team.team_id },
            channel: { id: 'C1', name: 'moji' },
            message_ts: '1547654324.000400',
            message: { text: 'I love it when a dog barks.', type: 'text', user: 'U04KB5WQR', ts: '1547654324.000400' },
            token: token,
            callback_id: 'emoji-text'
          }.to_json
          expect(last_response.status).to eq 201
        end
      end
    end
    after do
      ENV.delete('SLACK_VERIFICATION_TOKEN')
    end
  end
end
