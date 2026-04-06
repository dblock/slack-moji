require 'spec_helper'

GSTATIC_URL_A = 'https://encrypted-tbn0.gstatic.com/images?q=tbn:a'.freeze
GSTATIC_URL_B = 'https://encrypted-tbn0.gstatic.com/images?q=tbn:b'.freeze
GSTATIC_URL_C = 'https://encrypted-tbn0.gstatic.com/images?q=tbn:c'.freeze

GSTATIC_HTML = <<~HTML.freeze
  <html><body>
    <img src="#{GSTATIC_URL_A}" />
    <img src="#{GSTATIC_URL_B}" />
    <img src="#{GSTATIC_URL_C}" />
  </body></html>
HTML

describe SlackMoji::ImageSearch do
  before do
    stub_request(:get, %r{google\.com/search})
      .to_return(status: 200, body: GSTATIC_HTML, headers: { 'Content-Type' => 'text/html' })
  end

  describe '.find' do
    it 'returns image URLs from Google Images' do
      urls = described_class.find('cat')
      expect(urls).not_to be_empty
      expect(urls).to all(include('gstatic.com'))
    end

    it 'returns at most the requested count' do
      urls = described_class.find('cat', 2)
      expect(urls.size).to be <= 2
    end

    it 'deduplicates results' do
      urls = described_class.find('cat', 10)
      expect(urls).to eq(urls.uniq)
    end
  end

  describe '.search_google' do
    it 'queries Google Images with keyword and returns URLs' do
      urls = described_class.search_google('cat', 5)
      expect(urls).to include(GSTATIC_URL_A, GSTATIC_URL_B, GSTATIC_URL_C)
    end

    it 'returns empty array on error' do
      stub_request(:get, %r{google\.com/search}).to_raise(StandardError)
      urls = described_class.search_google('cat', 5)
      expect(urls).to eq([])
    end
  end
end
