module Api
  module Presenters
    module RootPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer

      link :self do |opts|
        "#{base_url(opts)}/api"
      end

      link :status do |opts|
        "#{base_url(opts)}/api/status"
      end

      link :subscriptions do |opts|
        "#{base_url(opts)}/api/subscriptions"
      end

      link :credit_cards do |opts|
        "#{base_url(opts)}/api/credit_cards"
      end

      link :user do |opts|
        {
          href: "#{base_url(opts)}/api/users/{id}",
          templated: true
        }
      end

      link :users do |opts|
        "#{base_url(opts)}/api/users"
      end

      link :teams do |opts|
        {
          href: "#{base_url(opts)}/api/teams/#{link_params(Api::Helpers::PaginationParameters::ALL, :active)}",
          templated: true
        }
      end

      link :team do |opts|
        {
          href: "#{base_url(opts)}/api/teams/{id}",
          templated: true
        }
      end

      private

      def base_url(opts)
        request = Grape::Request.new(opts[:env])
        request.base_url
      end

      def link_params(*args)
        "{?#{args.join(',')}}"
      end
    end
  end
end
