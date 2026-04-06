require 'spec_helper'

SEARCH_IMAGE_URL_A = 'https://images.emojiterra.com/google/cat.png'.freeze
SEARCH_IMAGE_URL_B = 'https://images.emojiterra.com/google/cat2.png'.freeze
SEARCH_DDG_VQD_HTML = '<html><body><script>vqd="4-abc123"</script></body></html>'.freeze
SEARCH_DDG_JSON = JSON.generate(results: [{ image: SEARCH_IMAGE_URL_A }, { image: SEARCH_IMAGE_URL_B }]).freeze

describe Api::Endpoints::SlackEndpoint do
  include Api::Test::EndpointTest

  context 'with a SLACK_VERIFICATION_TOKEN' do
    let(:token) { 'slack-verification-token' }
    let(:team) { Fabricate(:team, subscribed: true) }
    let(:user) { Fabricate(:user, team: team) }

    before do
      ENV['SLACK_VERIFICATION_TOKEN'] = token
    end

    after do
      ENV.delete('SLACK_VERIFICATION_TOKEN')
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
            {
              'fallback' => "https://slack.com/oauth/authorize?scope=users.profile:write&client_id=&redirect_uri=%2Fauthorize&team=#{user.team.team_id}&state=#{user.id}",
              'actions' => [
                {
                  'type' => 'button',
                  'text' => 'Allow Moji',
                  'url' => "https://slack.com/oauth/authorize?scope=users.profile:write&client_id=&redirect_uri=%2Fauthorize&team=#{user.team.team_id}&state=#{user.id}"
                }
              ]
            }
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

      context 'subscription expired' do
        let(:team) { Fabricate(:team, subscribed: false) }

        it 'errors' do
          post '/api/slack/command',
               command: '/moji',
               text: 'me',
               channel_id: 'C1',
               channel_name: 'channel',
               user_id: user.user_id,
               team_id: user.team.team_id,
               token: token
          expect(last_response.status).to eq 201
          expect(last_response.body).to eq({
            message: team.subscribe_text,
            user: user.user_id,
            channel: 'C1'
          }.to_json)
        end
      end

      context 'search command' do
        before do
          stub_request(:get, %r{duckduckgo\.com/\?q=})
            .to_return(status: 200, body: SEARCH_DDG_VQD_HTML, headers: { 'Content-Type' => 'text/html' })
          stub_request(:get, %r{duckduckgo\.com/i\.js})
            .to_return(status: 200, body: SEARCH_DDG_JSON, headers: { 'Content-Type' => 'application/json' })
        end

        it 'returns image results as Block Kit context elements with numbered buttons' do
          post '/api/slack/command',
               command: '/moji',
               text: 'search cat',
               channel_id: 'C1',
               channel_name: 'channel',
               user_id: user.user_id,
               team_id: user.team.team_id,
               token: token
          expect(last_response.status).to eq 201
          response = JSON.parse(last_response.body)
          blocks = response['blocks']
          expect(blocks).not_to be_nil
          expect(response['text']).to include('cat')
          section = blocks.find { |b| b['type'] == 'section' }
          expect(section['text']['text']).to include('cat')
          context_block = blocks.find { |b| b['type'] == 'context' }
          expect(context_block['elements'].first['image_url']).to eq(SEARCH_IMAGE_URL_A)
          input_block = blocks.find { |b| b['type'] == 'input' }
          expect(input_block['block_id']).to eq('emoji_name_block')
          expect(input_block['element']['initial_value']).to eq('cat')
          actions_block = blocks.find { |b| b['type'] == 'actions' }
          first_button = actions_block['elements'].first
          expect(first_button['text']['text']).to eq('1')
          expect(first_button['action_id']).to eq('search-select-1')
          expect(first_button['value']).to eq(SEARCH_IMAGE_URL_A)
        end

        it 'returns an error when no keyword is given' do
          post '/api/slack/command',
               command: '/moji',
               text: 'search',
               channel_id: 'C1',
               channel_name: 'channel',
               user_id: user.user_id,
               team_id: user.team.team_id,
               token: token
          expect(last_response.status).to eq 201
          response = JSON.parse(last_response.body)
          expect(response['message']).to include('Please provide a keyword')
        end

        it 'works without moji authorization' do
          post '/api/slack/command',
               command: '/moji',
               text: 'search cat',
               channel_id: 'C1',
               channel_name: 'channel',
               user_id: user.user_id,
               team_id: user.team.team_id,
               token: token
          expect(last_response.status).to eq 201
          response = JSON.parse(last_response.body)
          expect(response['blocks']).not_to be_nil
        end
      end

      context 'search command with expired subscription' do
        let(:team) { Fabricate(:team, subscribed: false) }

        before do
          stub_request(:get, %r{duckduckgo\.com/\?q=})
            .to_return(status: 200, body: SEARCH_DDG_VQD_HTML, headers: { 'Content-Type' => 'text/html' })
          stub_request(:get, %r{duckduckgo\.com/i\.js})
            .to_return(status: 200, body: SEARCH_DDG_JSON, headers: { 'Content-Type' => 'application/json' })
        end

        it 'errors on expired subscription' do
          post '/api/slack/command',
               command: '/moji',
               text: 'search cat',
               channel_id: 'C1',
               channel_name: 'channel',
               user_id: user.user_id,
               team_id: user.team.team_id,
               token: token
          expect(last_response.status).to eq 201
          response = JSON.parse(last_response.body)
          expect(response['message']).to eq(team.subscribe_text)
        end
      end
    end

    context 'interactive buttons' do
      context 'search-select' do
        it 'confirms selected image URL (Block Kit action)' do
          post '/api/slack/action', payload: {
            type: 'block_actions',
            actions: [{ action_id: 'search-select-1', value: SEARCH_IMAGE_URL_A }],
            state: { values: { emoji_name_block: { emoji_name: { value: 'happy-cat' } } } },
            channel: { id: 'C1', name: 'moji' },
            user: { id: user.user_id },
            team: { id: team.team_id },
            token: token
          }.to_json
          expect(last_response.status).to eq 201
          response = JSON.parse(last_response.body)
          expect(response['text']).to include('happy-cat')
          expect(response['text']).to include(SEARCH_IMAGE_URL_A)
        end

        it 'falls back to "emoji" when no name is provided' do
          post '/api/slack/action', payload: {
            type: 'block_actions',
            actions: [{ action_id: 'search-select-1', value: SEARCH_IMAGE_URL_A }],
            channel: { id: 'C1', name: 'moji' },
            user: { id: user.user_id },
            team: { id: team.team_id },
            token: token
          }.to_json
          expect(last_response.status).to eq 201
          response = JSON.parse(last_response.body)
          expect(response['text']).to include(':emoji:')
        end
      end

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
          expect_any_instance_of(Slack::Web::Client).to receive(:reactions_add).twice
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

      context 'subscription expired' do
        let(:team) { Fabricate(:team, subscribed: false) }

        it 'errors' do
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
          expect(last_response.body).to eq({
            message: team.subscribe_text
          }.to_json)
        end
      end
    end
  end
end
