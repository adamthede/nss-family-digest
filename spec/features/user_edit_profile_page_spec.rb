require 'spec_helper'

feature "User edits profile" do
  let!(:adam) { Fabricate(:user, email: "adam@cityofthedes.com") }
  scenario "happy path" do
    login_as adam
    visit edit_user_path(adam)
    attach_file "Profile image", 'spec/data/db-schema.jpg'
    click_button "Update Profile"
    page.should have_content "Your profile was successfully updated."
    page.should have_css('div.profile-image')
    within('div.profile-image') do
      page.find('img')['src'].should have_content '/thumb_db-schema.jpg'
    end
  end
end
