require 'spec_helper'

GSTATIC_URL_A = 'https://images.emojiterra.com/google/cat.png'.freeze
GSTATIC_URL_B = 'https://images.emojiterra.com/google/cat2.png'.freeze
GSTATIC_URL_C = 'https://images.emojiterra.com/google/cat3.png'.freeze

DDG_VQD_HTML = '<html><body><script>vqd="4-abc123"</script></body></html>'.freeze
DDG_IMAGE_JSON = JSON.generate(
  results: [
    { image: GSTATIC_URL_A },
    { image: GSTATIC_URL_B },
    { image: GSTATIC_URL_C }
  ]
).freeze

describe SlackMoji::ImageSearch do
  before do
    stub_request(:get, %r{duckduckgo\.com/\?q=})
      .to_return(status: 200, body: DDG_VQD_HTML, headers: { 'Content-Type' => 'text/html' })
    stub_request(:get, %r{duckduckgo\.com/i\.js})
      .to_return(status: 200, body: DDG_IMAGE_JSON, headers: { 'Content-Type' => 'application/json' })
  end

  describe '.find' do
    it 'returns image URLs' do
      urls = described_class.find('cat')
      expect(urls).not_to be_empty
      expect(urls.first).to eq(GSTATIC_URL_A)
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

  describe '.search_duckduckgo' do
    it 'returns image URLs from DuckDuckGo' do
      urls = described_class.search_duckduckgo('cat', 5)
      expect(urls).to include(GSTATIC_URL_A, GSTATIC_URL_B, GSTATIC_URL_C)
    end

    it 'returns empty array on error' do
      stub_request(:get, %r{duckduckgo\.com/i\.js}).to_raise(StandardError)
      urls = described_class.search_duckduckgo('cat', 5)
      expect(urls).to eq([])
    end

    it 'returns empty array when vqd is missing' do
      stub_request(:get, %r{duckduckgo\.com/\?q=})
        .to_return(status: 200, body: '<html></html>', headers: { 'Content-Type' => 'text/html' })
      urls = described_class.search_duckduckgo('cat', 5)
      expect(urls).to eq([])
    end
  end

  describe '.fetch_vqd' do
    it 'extracts the vqd token from the DuckDuckGo homepage' do
      vqd = described_class.fetch_vqd('cat')
      expect(vqd).to eq('4-abc123')
    end

    it 'returns nil on error' do
      stub_request(:get, %r{duckduckgo\.com/\?q=}).to_raise(StandardError)
      expect(described_class.fetch_vqd('cat')).to be_nil
    end
  end
end
