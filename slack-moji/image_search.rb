module SlackMoji
  class ImageSearch
    GOOGLE_URL = 'https://www.google.com/search?q=%<query>s&source=lnms&tbm=isch&tbs=isz:i'.freeze
    APPEND_TERMS = ['', 'emoji', 'cartoon'].freeze
    DEFAULT_COUNT = 5

    def self.find(keyword, count = DEFAULT_COUNT)
      images = []

      APPEND_TERMS.each do |term|
        search_term = [keyword, term].reject(&:empty?).join(' ')
        images.concat(search_google(search_term, count))
        break if images.size >= count
      end

      images.uniq.first(count)
    end

    def self.search_google(query, count)
      encoded = URI.encode_www_form_component(query)
      url = format(GOOGLE_URL, query: encoded)
      response = HTTParty.get(url, headers: { 'User-Agent' => 'Mozilla/5.0' })
      doc = Nokogiri::HTML(response.body)
      doc.css('img[src*="gstatic.com"]').map { |img| img['src'] }.first(count)
    rescue StandardError
      []
    end
  end
end
