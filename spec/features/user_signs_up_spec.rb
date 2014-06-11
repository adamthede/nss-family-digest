require 'spec_helper'

feature "User signs up" do
  scenario "successful user sign up" do
    visit '/'
    clink_link "I'm Ready!"
    pending
    fill_in "Email", with: "adam@example.com"
    fill_in "Username", with: "Adam"
    fill_in "Password", with: "mypassword"
    fill_in "Password Confirmation", with: "mypassword"
    click_button "Sign up"
    page.should have_content "Welcome to Family Digest, Adam!"
    current_path.should == dashboard_path
  end

  scenario "failed signup" do
    pending
    User.create(email: "adam@example.com", username: "Adam", password: "password", password_confirmation: "password")
    visit '/'
    click_link "I'm Ready!"
    fill_in "Email", with: "adam@example.com"
    fill_in "Username", with: "Adam"
    fill_in "Password", with: "mypassword"
    fill_in "Password confirmation", with: "notthesame"
    click_button "Sign up"
    page.should_not have_content "Welcome to Family Digest"
    page.should have_content "Your account could not be created"

    page.should have_error("already exists", on: "Email")
    page.should have_error("must match confirmation", on: "Password")
    page.should have_error("must be unique", on: "Username")
  end
end
