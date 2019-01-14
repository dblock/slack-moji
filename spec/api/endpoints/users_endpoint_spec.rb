require 'spec_helper'

describe Api::Endpoints::UsersEndpoint do
  include Api::Test::EndpointTest

  context 'users' do
    let(:user) { Fabricate(:user) }
    it 'authorizes a user with moji' do
      expect_any_instance_of(User).to receive(:authorize!).with('code')
      client.user(id: user.id)._put(code: 'code')
    end
  end
end
