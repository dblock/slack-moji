module SlackMoji
  class Service < SlackRubyBotServer::Service
    def self.url
      ENV['URL'] || (ENV['RACK_ENV'] == 'development' ? 'http://localhost:5000' : 'https://moji.playplay.io')
    end
  end
end
