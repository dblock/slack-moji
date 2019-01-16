module Api
  module Endpoints
    class SlackEndpointCommands
      class Command
        attr_reader :action, :arg, :channel_id, :channel_name, :user_id, :team_id, :text, :image_url, :token, :response_url, :trigger_id, :type, :submission

        def initialize(params)
          if params.key?(:payload)
            @action = params[:payload][:callback_id]
            @channel_id = params[:payload][:channel][:id]
            @channel_name = params[:payload][:channel][:name]
            @user_id = params[:payload][:user][:id]
            @team_id = params[:payload][:team][:id]
            @type = params[:payload][:type]
            if params[:payload].key?(:actions)
              @arg = params[:payload][:actions][0][:value]
              @text = [action, arg].join(' ')
            elsif params[:payload].key?(:message)
              payload_message = params[:payload][:message]
              @text = payload_message[:text]
              if payload_message.key?(:attachments)
                payload_message[:attachments].each do |attachment|
                  @text = [@text, attachment[:image_url]].compact.join("\n")
                end
              end
            end
            @token = params[:payload][:token]
            @response_url = params[:payload][:response_url]
            @trigger_id = params[:payload][:trigger_id]
            @submission = params[:payload][:submission]
          else
            @text = params[:text]
            @action, @arg = text.split(/\s/, 2)
            @channel_id = params[:channel_id]
            @channel_name = params[:channel_name]
            @user_id = params[:user_id]
            @team_id = params[:team_id]
            @token = params[:token]
          end
        end

        def user
          @user ||= ::User.find_create_or_update_by_team_and_slack_id!(
            team_id,
            user_id
          )
        end

        def slack_verification_token!
          return unless ENV.key?('SLACK_VERIFICATION_TOKEN')
          return if token == ENV['SLACK_VERIFICATION_TOKEN']

          throw :error, status: 401, message: 'Message token is not coming from Slack.'
        end
      end
    end
  end
end
