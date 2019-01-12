module SlackRubyBot
  module Hooks
    class Message
      # HACK: order command classes predictably
      def command_classes
        [
          SlackMoji::Commands::Help,
          SlackMoji::Commands::Info,
          SlackMoji::Commands::Subscription
        ]
      end
    end
  end
end
