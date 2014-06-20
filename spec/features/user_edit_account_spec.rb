require 'spec_helper'

feature "User edits account" do
  let!(:adam) { Fabricate(:user, email: "adam@cityofthedes.com") }
  scenario "happy path" do
    login_as adam
    visit '/users/edit'
    fill_in "Email", with: "at@example.com"
    fill_in "Password", with: "newpassword"
    fill_in "Password confirmation", with: "newpassword"
    fill_in "Current password", with: "password"
    click_button "Update"
    page.should have_content "You updated your account successfully."
    page.should_not have_link("Update")
  end

  scenario "failed account edit" do
    login_as adam
    visit '/users/edit'
    fill_in "Email", with: "at@example.com"
    fill_in "Password", with: "newpassword"
    fill_in "Password confirmation", with: "wrongpassword"
    fill_in "Current password", with: "password"
    click_button "Update"
    page.should have_content "Password confirmation doesn't match Password"
    page.should have_error("doesn't match Password", on: "Password confirmation")
  end
end
