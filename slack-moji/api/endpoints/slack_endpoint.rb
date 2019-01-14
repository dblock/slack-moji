module Api
  module Endpoints
    class SlackEndpoint < Grape::API
      format :json

      namespace :slack do
        desc 'Respond to slash commands.'
        params do
          requires :command, type: String
          requires :text, type: String
          requires :token, type: String
          requires :user_id, type: String
          requires :channel_id, type: String
          requires :team_id, type: String
        end
        post '/command' do
          token = params['token']
          error!('Message token is not coming from Slack.', 401) if ENV.key?('SLACK_VERIFICATION_TOKEN') && token != ENV['SLACK_VERIFICATION_TOKEN']

          channel_id = params['channel_id']
          user_id = params['user_id']
          team_id = params['team_id']
          text = params['text']

          user = ::User.find_create_or_update_by_team_and_slack_id!(team_id, user_id)

          if user.access_token
            case text
            when 'me' then
              user.to_slack_emoji_question.merge(user: user_id, channel: channel_id)
            else
              { message: "Sorry, I don't understand the `#{text}` command.", user: user_id, channel: channel_id }
            end
          else
            user.to_slack_auth_request.merge(user: user_id, channel: channel_id)
          end
        end

        desc 'Respond to interactive slack buttons and actions.'
        params do
          requires :payload, type: JSON do
            requires :token, type: String
            requires :callback_id, type: String
            requires :channel, type: Hash do
              requires :id, type: String
            end
            requires :user, type: Hash do
              requires :id, type: String
            end
            requires :team, type: Hash do
              requires :id, type: String
            end
            requires :actions, type: Array do
              requires :value, type: String
            end
          end
        end
        post '/action' do
          payload = params['payload']
          token = payload['token']
          error!('Message token is not coming from Slack.', 401) if ENV.key?('SLACK_VERIFICATION_TOKEN') && token != ENV['SLACK_VERIFICATION_TOKEN']

          callback_id = payload['callback_id']
          channel_id = payload['channel']['id']
          channel_name = payload['channel']['name']
          user_id = payload['user']['id']
          team_id = payload['team']['id']

          user = ::User.find_create_or_update_by_team_and_slack_id!(team_id, user_id)

          case callback_id
          when 'emoji-count'
            emoji_count = payload['actions'].first['value'].to_i
            user.update_attributes!(emoji_count: emoji_count, emoji: emoji_count > 0)
            user.emoji!
            user.to_slack_emoji_question("Got it, #{user.emoji_text.downcase}.")
          else
            error!("Callback #{callback_id} is not supported.", 404)
          end
        end
      end
    end
  end
end
