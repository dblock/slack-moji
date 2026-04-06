module Api
  module Endpoints
    class SlackEndpointCommands
      class Command
        attr_reader :action, :arg, :channel_id, :channel_name, :user_id, :team_id, :text, :image_url, :token,
                    :response_url, :trigger_id, :type, :submission, :message_ts, :emoji_name

        def initialize(params)
          if params.key?(:payload)
            payload = params[:payload]
            @channel_id = payload[:channel][:id]
            @channel_name = payload[:channel][:name]
            @user_id = payload[:user][:id]
            @team_id = payload[:team][:id]
            @type = payload[:type]
            @message_ts = payload[:message_ts]
            if params[:payload].key?(:actions)
              first_action = payload[:actions][0]
              # Support both Block Kit (action_id) and legacy attachments (callback_id)
              @action = payload[:callback_id] || first_action[:action_id]&.sub(/-\d+$/, '')
              @arg = first_action[:value]
              @emoji_name = payload.dig(:state, :values, :emoji_name_block, :emoji_name, :value)
              @text = [action, arg].join(' ')
            elsif params[:payload].key?(:message)
              @action = payload[:callback_id]
              payload_message = payload[:message]
              @text = payload_message[:text]
              @message_ts ||= payload_message[:ts]
              if payload_message.key?(:attachments)
                payload_message[:attachments].each do |attachment|
                  @text = [@text, attachment[:image_url]].compact.join("\n")
                end
              end
            else
              @action = payload[:callback_id]
            end
            @token = payload[:token]
            @response_url = payload[:response_url]
            @trigger_id = payload[:trigger_id]
            @submission = payload[:submission]
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

        def team
          user&.team
        end

        def slack_verification_token!
          return unless ENV.key?('SLACK_VERIFICATION_TOKEN')
          return if token == ENV['SLACK_VERIFICATION_TOKEN']

          throw :error, status: 401, message: 'Message token is not coming from Slack.'
        end

        def search!
          keyword = arg
          return { message: 'Please provide a keyword, e.g. `/moji search cat`.' } if keyword.blank?

          urls = SlackMoji::ImageSearch.find(keyword)
          return { message: "No images found for \"#{keyword}\"." } if urls.empty?

          to_slack_search_results(keyword, urls)
        end

        def search_select!
          url = arg
          return { message: 'No image URL provided.' } if url.blank?

          name = emoji_name.presence || 'emoji'
          sanitized_name = name.gsub(/[^a-z0-9_-]/i, '_').downcase.gsub(/_+/, '_').gsub(/^_|_$/, '')
          return { message: 'Emoji name is invalid.' } if sanitized_name.blank?

          team.slack_client.admin_emoji_add(name: sanitized_name, url: url)
          { text: "Added :#{sanitized_name}: to your workspace!" }
        rescue Slack::Web::Api::Errors::SlackError => e
          { message: "Failed to add emoji: #{e.message}." }
        end

        def emoji_count!
          emoji_count = arg.to_i
          user.update_attributes!(emoji_count: emoji_count, emoji: emoji_count.positive?)
          user.emoji!
          user.to_slack_emoji_question("Got it, #{user.emoji_text.downcase}.")
        end

        def emoji_text!
          case type
          when 'message_action'
            text.scan(/\w{3,}/) do |word|
              emojis = EmojiData.find_by_short_name(word)
              next unless emojis&.any?

              emoji = emojis[rand(emojis.count)]
              user.team.slack_client.reactions_add(
                name: emoji.short_name,
                channel: channel_id,
                timestamp: message_ts
              )
            end
            { message: 'OK' }
          else
            { message: 'Unsupported message type.' }
          end
        end

        private

        def to_slack_search_results(keyword, urls)
          image_elements = urls.map.with_index(1) do |url, i|
            { type: 'image', image_url: url, alt_text: "Option #{i}" }
          end
          buttons = urls.map.with_index(1) do |url, i|
            {
              type: 'button',
              text: { type: 'plain_text', text: i.to_s },
              action_id: "search-select-#{i}",
              value: url
            }
          end
          sanitized_keyword = keyword.gsub(/[^a-z0-9_-]/i, '_').downcase
          {
            text: "Search results for \"#{keyword}\":",
            blocks: [
              { type: 'section', text: { type: 'mrkdwn', text: "Search results for *#{keyword}*:" } },
              { type: 'context', elements: image_elements },
              {
                type: 'input',
                block_id: 'emoji_name_block',
                label: { type: 'plain_text', text: 'Emoji name' },
                element: {
                  type: 'plain_text_input',
                  action_id: 'emoji_name',
                  initial_value: sanitized_keyword,
                  placeholder: { type: 'plain_text', text: 'e.g. dancing-cat' }
                }
              },
              { type: 'actions', elements: buttons }
            ]
          }
        end
      end
    end
  end
end
