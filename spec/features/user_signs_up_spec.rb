require 'spec_helper'

feature "User signs up" do
  scenario "successful user sign up" do
    visit '/'
    click_link "I'm Ready!"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "mypassword"
    fill_in "Password confirmation", with: "mypassword"
    click_button "Sign up"
    page.should have_content "Welcome to Family Digest!"
    page.should_not have_link("I'm Ready!")

    click_link "Sign out"
    click_link "Sign in"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "mypassword"
    click_button "Log in"
    page.should have_content "You have signed in successfully"
  end

  scenario "failed signup" do
    User.create(email: "adam@example.com", password: "password", password_confirmation: "password")
    visit '/'
    click_link "I'm Ready!"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "mypassword"
    fill_in "Password confirmation", with: "notthesame"
    click_button "Sign up"
    page.should_not have_content "Welcome to Family Digest!"
    page.should have_content "Your account could not be created"

    page.should have_error("has already been taken", on: "Email")
    page.should have_error("doesn't match Password", on: "Password confirmation")
  end
end
