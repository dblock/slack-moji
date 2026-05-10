module SlackMoji
  class ImageSearch
    DDG_HOME_URL = 'https://duckduckgo.com/'.freeze
    DDG_IMAGE_URL = 'https://duckduckgo.com/i.js'.freeze
    HEADERS = { 'User-Agent' => 'Mozilla/5.0' }.freeze
    DEFAULT_COUNT = 5

    def self.find(keyword, count = DEFAULT_COUNT)
      search_duckduckgo(keyword, count).uniq.first(count)
    end

    def self.search_duckduckgo(query, count)
      vqd = fetch_vqd(query)
      return [] unless vqd

      response = HTTParty.get(DDG_IMAGE_URL,
                              query: { q: query, o: 'json', vqd: vqd, f: 'type:transparent', p: '1' },
                              headers: HEADERS.merge('Referer' => DDG_HOME_URL))
      data = JSON.parse(response.body)
      (data['results'] || []).map { |r| r['image'] }.compact.first(count)
    rescue StandardError
      []
    end

    def self.fetch_vqd(query)
      response = HTTParty.get(DDG_HOME_URL, query: { q: query }, headers: HEADERS)
      response.body[/vqd=['"]([^'"]+)['"]/, 1]
    rescue StandardError
      nil
    end
  end
end
