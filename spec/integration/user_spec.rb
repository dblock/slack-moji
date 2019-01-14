require 'spec_helper'

describe 'Users', js: true, type: :feature do
  let!(:user) { Fabricate(:user) }
  context 'oauth', vcr: { cassette_name: 'auth_test' } do
    it 'authorizes a user' do
      expect_any_instance_of(User).to receive(:authorize!).with('code')
      visit "/authorize?code=code&state=#{user.id}"
      expect(page.find('#messages')).to have_content 'User successfully authorized!'
    end
  end
end
