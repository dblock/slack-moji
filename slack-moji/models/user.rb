class User
  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id, type: String
  field :user_name, type: String

  field :is_bot, type: Boolean, default: false

  belongs_to :team, index: true
  validates_presence_of :team

  index({ user_id: 1, team_id: 1 }, unique: true)
  index(user_name: 1, team_id: 1)

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

  def to_s
    "user_id=#{user_id}, user_name=#{user_name}"
  end
end
