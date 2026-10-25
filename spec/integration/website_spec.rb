require 'spec_helper'

describe 'Website', :js, type: :feature do
  it 'opens help with the keyboard without resizing the background' do
    visit '/help.html'
    background_height = page.evaluate_script('getComputedStyle(document.body, "::before").height')
    within('details', text: 'How do I turn on emoji status?') do
      expect(page).to have_no_css('p')
      find('summary').send_keys(:enter)
      expect(page).to have_css('p', text: '/moji me')
      expect(page.evaluate_script('getComputedStyle(document.body, "::before").position')).to eq 'fixed'
      expect(page.evaluate_script('getComputedStyle(document.body, "::before").height')).to eq background_height
      find('summary').send_keys(:enter)
      expect(page).to have_no_css('p')
    end
  end

  it 'keeps navigation and expanded help usable at 320 pixels' do
    visit '/'
    page.execute_script("document.body.innerHTML = '<iframe id=\"mobile\" title=\"Mobile\" src=\"/\" width=\"320\" style=\"border:0\"></iframe>'")
    within_frame('mobile') do
      expect(page.evaluate_script('window.innerWidth')).to eq 320
      expect(page).to have_css('html') { |html| html.evaluate_script('this.scrollWidth <= window.innerWidth') }
      within('nav') { click_link 'Help' }
      expect(page).to have_css('h1', exact_text: 'Help')
      all('details > summary').each(&:click)
      expect(page).to have_css('html') { |html| html.evaluate_script('this.scrollWidth <= window.innerWidth') }
    end
  end
end
