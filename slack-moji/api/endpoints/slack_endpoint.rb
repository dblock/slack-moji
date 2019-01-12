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

          result = case text
                   when 'xyz' then
                   # TODO
                   else
                     error!("I don't understand the `#{text}` command.", 400)
                   end

          result.merge(
            user: user_id, channel: channel_id
          )
        end
      end
    end
  end
end
