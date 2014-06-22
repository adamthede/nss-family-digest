require 'spec_helper'

feature "User signs up" do
  scenario "successful user sign up" do
    visit root_path
    click_link "I'm Ready!"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "mypassword"
    fill_in "Re-enter Password", with: "mypassword"
    click_button "Sign up"
    page.should have_content "Welcome to Family Digest!"
    page.should_not have_link("I'm Ready!")

    click_link "Sign out"
    click_link "Sign in"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "mypassword"
    click_button "Sign in"
    page.should have_content "You have signed in successfully"
  end

  scenario "failed signup" do
    Fabricate(:user, email: "adam@example.com")
    visit root_path
    click_link "I'm Ready!"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "mypassword"
    fill_in "Re-enter Password", with: "notthesame"
    click_button "Sign up"
    page.should_not have_content "Welcome to Family Digest!"
    page.should have_content "Your account could not be created"

    page.should have_error("has already been taken", on: "Email")
    page.should have_error("doesn't match Password", on: "Password confirmation")
  end
end
