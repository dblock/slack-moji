require 'spec_helper'

describe Api::Middleware do
  include Rack::Test::Methods

  let(:app) { described_class.instance }

  %w[/ /help.html /privacy.html /subscribe.html /update_cc.html /authorize.html].each do |path|
    it "versions local assets and revalidates #{path}" do
      get path

      expect(last_response.status).to eq 200
      expect(last_response.headers['Cache-Control']).to eq 'private, no-cache'
      document = Capybara.string(last_response.body)
      assets = document.all('script[src^="/"], link[href^="/"], img[src^="/"], meta[name="msapplication-TileImage"]', visible: :all)
      expect(assets).not_to be_empty
      expect(assets.map { |asset| asset[:src] || asset[:href] || asset[:content] }).to all(match(/\?v=[a-f0-9]{64}\z/))
    end
  end

  it 'versions checkout images in JavaScript and data attributes' do
    image = "/img/icon.png?v=#{Digest::SHA256.file('public/img/icon.png').hexdigest}"
    get '/subscribe.html'
    expect(last_response.body).to include("image: #{image.to_json}")

    get '/update_cc.html'
    expect(Capybara.string(last_response.body).find('script[data-image]', visible: :all)['data-image']).to eq image
  end

  it 'revalidates generated CSS after a wave-artwork-only change' do
    get '/styles.css'
    image_hash = Digest::SHA256.file('public/img/waves.svg').hexdigest
    expect(last_response.content_type).to eq 'text/css; charset=utf-8'
    expect(last_response.headers['Cache-Control']).to eq 'private, no-cache'
    expect(last_response.body).to include("/img/waves.svg?v=#{image_hash}")

    allow(Digest::SHA256).to receive(:file).and_call_original
    allow(Digest::SHA256).to receive(:file).with('public/img/waves.svg').and_return(double(hexdigest: 'f' * 64))
    get '/styles.css', {}, 'HTTP_IF_MODIFIED_SINCE' => File.mtime('public/styles.css.erb').httpdate
    expect(last_response.status).to eq 200
    expect(last_response.body).to include("/img/waves.svg?v=#{'f' * 64}")
    expect(last_response.body).not_to include(image_hash)
  end

  it 'returns a content ETag and a bodyless 304 for matching static content' do
    get '/scripts/common.js'
    etag = last_response.headers['ETag']
    expect(etag).to eq %("#{Digest::SHA256.file('public/scripts/common.js').hexdigest}")
    expect(last_response.headers['Last-Modified']).to eq File.mtime('public/scripts/common.js').httpdate
    expect(last_response.headers['Cache-Control'].to_s).not_to match(/immutable|max-age/)

    get '/scripts/common.js', {}, 'HTTP_IF_NONE_MATCH' => etag
    expect(last_response.status).to eq 304
    expect(last_response.body).to be_empty
  end

  it 'ignores a matching timestamp when the content ETag does not match' do
    get '/scripts/common.js', {}, 'HTTP_IF_NONE_MATCH' => '"old-content"',
                                  'HTTP_IF_MODIFIED_SINCE' => File.mtime('public/scripts/common.js').httpdate

    expect(last_response.status).to eq 200
    expect(last_response.body).to eq File.read('public/scripts/common.js')
  end
end
