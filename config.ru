$LOAD_PATH.unshift(File.dirname(__FILE__))

ENV['RACK_ENV'] ||= 'development'

require 'bundler/setup'
Bundler.require :default, ENV.fetch('RACK_ENV', nil)

require 'slack-ruby-bot-server'
require 'slack-moji'

SlackRubyBotServer::RealTime.configure do |config|
  config.server_class = SlackMoji::Server
end

NewRelic::Agent.manual_start

SlackMoji::App.instance.prepare!

Thread.abort_on_exception = true

Thread.new do
  SlackRubyBotServer::Service.instance.start_from_database!
  SlackMoji::App.instance.after_start!
end

run Api::Middleware.instance
