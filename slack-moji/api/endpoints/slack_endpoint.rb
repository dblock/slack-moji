require_relative 'command'

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
          requires :channel_name, type: String
          requires :team_id, type: String
        end
        post '/command' do
          command = SlackEndpointCommands::Command.new(params)
          command.slack_verification_token!

          response = if command.user.access_token
                       case command.action
                       when 'me' then
                         command.user.to_slack_emoji_question
                       else
                         { message: "Sorry, I don't understand the `#{command.action}` command." }
                       end
                     else
                       command.user.to_slack_auth_request
                     end

          response.merge(user: command.user_id, channel: command.channel_id)
        end

        desc 'Respond to interactive slack buttons and actions.'
        params do
          requires :payload, type: JSON do
            requires :token, type: String
            requires :callback_id, type: String
            optional :type, type: String
            optional :trigger_id, type: String
            optional :response_url, type: String
            requires :channel, type: Hash do
              requires :id, type: String
              optional :name, type: String
            end
            requires :user, type: Hash do
              requires :id, type: String
              optional :name, type: String
            end
            requires :team, type: Hash do
              requires :id, type: String
              optional :domain, type: String
            end
            optional :actions, type: Array do
              requires :value, type: String
            end
            optional :message, type: Hash do
              requires :type, type: String
              requires :user, type: String
              requires :ts, type: String
              requires :text, type: String
            end
          end
        end
        post '/action' do
          command = SlackEndpointCommands::Command.new(params)
          command.slack_verification_token!

          case command.action
          when 'emoji-count'
            emoji_count = command.arg.to_i
            command.user.update_attributes!(emoji_count: emoji_count, emoji: emoji_count > 0)
            command.user.emoji!
            command.user.to_slack_emoji_question("Got it, #{command.user.emoji_text.downcase}.")
          else
            { message: "Sorry, I don't understand the `#{command.callback_id}` command." }
          end
        end
      end
    end
  end
end
