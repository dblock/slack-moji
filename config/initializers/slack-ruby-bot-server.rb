SlackRubyBotServer.configure do |config|
  config.oauth_version = :v1
  config.oauth_scope = %w[bot commands]
end
