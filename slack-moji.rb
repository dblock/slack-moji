ENV['RACK_ENV'] ||= 'development'

require 'bundler/setup'
Bundler.require :default, ENV.fetch('RACK_ENV', nil)

Dir["#{File.expand_path('config/initializers', __dir__)}/**/*.rb"].each do |file|
  require file
end

Mongoid.load! File.expand_path('config/mongoid.yml', __dir__), ENV.fetch('RACK_ENV', nil)

require 'slack-ruby-bot'
require 'slack-moji/version'
require 'slack-moji/service'
require 'slack-moji/info'
require 'slack-moji/models'
require 'slack-moji/api'
require 'slack-moji/app'
require 'slack-moji/server'
require 'slack-moji/commands'
