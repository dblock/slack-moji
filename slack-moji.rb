ENV['RACK_ENV'] ||= 'development'

require 'bundler/setup'
Bundler.require :default, ENV['RACK_ENV']

Dir[File.expand_path('../config/initializers', __FILE__) + '/**/*.rb'].each do |file|
  require file
end

Mongoid.load! File.expand_path('../config/mongoid.yml', __FILE__), ENV['RACK_ENV']

require 'slack-ruby-bot'
require 'slack-moji/version'
require 'slack-moji/service'
require 'slack-moji/info'
require 'slack-moji/models'
require 'slack-moji/api'
require 'slack-moji/app'
require 'slack-moji/server'
require 'slack-moji/commands'
