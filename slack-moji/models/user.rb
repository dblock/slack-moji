class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Enum

  field :user_id, type: String
  field :user_name, type: String
  field :access_token, type: String

  field :is_bot, type: Boolean, default: false
  enum :status, %i[unsubscribed emoji] # , :github]

  belongs_to :team, index: true
  validates_presence_of :team

  index({ user_id: 1, team_id: 1 }, unique: true)
  index(user_name: 1, team_id: 1)

  scope :with_emoji, -> { where(status_type: 'emoji', :access_token.ne => nil) }

  def slack_mention
    "<@#{user_id}>"
  end

  def self.find_by_slack_mention!(team, user_name)
    query = user_name =~ /^<@(.*)>$/ ? { user_id: ::Regexp.last_match[1] } : { user_name: ::Regexp.new("^#{user_name}$", 'i') }
    user = User.where(query.merge(team: team)).first
    raise SlackMoji::Error, "I don't know who #{user_name} is!" unless user
    user
  end

  def self.find_create_or_update_by_team_and_slack_id!(team_id, user_id)
    team = Team.where(team_id: team_id).first || raise("Cannot find team ID #{team_id}")
    user = User.where(team: team, user_id: user_id).first || User.create!(team: team, user_id: user_id)
    user
  end

  # Find an existing record, update the username if necessary, otherwise create a user record.
  def self.find_create_or_update_by_slack_id!(client, slack_id)
    instance = User.where(team: client.owner, user_id: slack_id).first
    instance_info = Hashie::Mash.new(client.web_client.users_info(user: slack_id)).user
    instance.update_attributes!(user_name: instance_info.name, is_bot: instance_info.is_bot) if instance && (instance.user_name != instance_info.name || instance.is_bot != instance_info.is_bot)
    instance ||= User.create!(team: client.owner, user_id: slack_id, user_name: instance_info.name, is_bot: instance_info.is_bot)
    instance
  end

  def inform!(message)
    team.slack_channels.map { |channel|
      next if user_id && !user_in_channel?(channel['id'])
      message_with_channel = message.merge(channel: channel['id'], as_user: true)
      logger.info "Posting '#{message_with_channel.to_json}' to #{team} on ##{channel['name']}."
      rc = team.slack_client.chat_postMessage(message_with_channel)

      {
        ts: rc['ts'],
        channel: channel['id']
      }
    }.compact
  end

  def dm!(message)
    im = team.slack_client.im_open(user: user_id)
    team.slack_client.chat_postMessage(message.merge(channel: im['channel']['id'], as_user: true))
  end

  def to_s
    "user_id=#{user_id}, user_name=#{user_name}"
  end

  def not_updating_status?
    status == :unsubscribed
  end

  def using_emoji_status?
    status == :emoji
  end

  def emoji_text
    if using_emoji_status?
      'No Emoji'
    else
      'Emoji'
    end
  end

  def moji_authorize_uri
    "#{ENV['APP_URL']}/authorize"
  end

  def slack_oauth_url
    "https://slack.com/oauth/authorize?scope=users.profile:write&client_id=#{ENV['SLACK_CLIENT_ID']}&redirect_uri=#{URI.encode(moji_authorize_uri)}&state=#{id}"
  end

  def to_slack_auth_request
    {
      text: 'Please allow more emoji in your profile.',
      attachments: [
        fallback: slack_oauth_url,
        actions: [
          type: 'button',
          text: 'Allow Moji',
          url: slack_oauth_url
        ]
      ]
    }
  end

  def to_slack_emoji_question(text = 'What type of updates would you like?')
    {
      text: text,
      attachments: [
        {
          text: '',
          attachment_type: 'default',
          callback_id: 'emoji-count',
          actions: [
            {
              name: 'status',
              text: 'No Emoji',
              type: 'button',
              value: 'unsubscribed',
              style: not_updating_status? ? 'primary' : 'default'
            },
            {
              name: 'status',
              text: 'Yes Emoji',
              type: 'emoji',
              value: 1,
              style: using_emoji_status? ? 'primary' : 'default'
            }
          ]
        }
      ]
    }
  end

  def authorize!(code)
    rc = team.slack_client.oauth_access(
      client_id: ENV['SLACK_CLIENT_ID'],
      client_secret: ENV['SLACK_CLIENT_SECRET'],
      code: code,
      redirect_uri: moji_authorize_uri
    )

    update_attributes!(access_token: rc['access_token'], status: :emoji)

    dm!(text: "May the moji be with you!\nTo configure try `/moji me`.")

    emoji!
  end

  def slack_client
    @slack_client ||= Slack::Web::Client.new(token: access_token)
  end

  def emoji!
    if using_emoji_status?
      emoji = EmojiData.all[rand(EmojiData.all.count)]
      logger.info "Emoji :#{emoji.short_name}: #{self}."
      slack_client.users_profile_set(profile: {
        status_text: Faker::GreekPhilosophers.quote,
        status_emoji: ":#{emoji.short_name}:"
      }.to_json)
    elsif not_updating_status?
      logger.info "Removing emoji #{self}."
      slack_client.users_profile_set(profile: {
        status_text: nil,
        status_emoji: nil
      }.to_json)
    end
  end
end
