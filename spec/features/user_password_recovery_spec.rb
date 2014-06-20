require 'spec_helper'

feature "User recovers password" do
  scenario "happy path email" do
    Fabricate(:user, email: "adam@example.com")
    visit '/'
    click_link "Sign in"
    click_link "Forgot your password?"
    fill_in "user_email", with: "adam@example.com"
    click_button "Send me reset password instructions"
    page.should have_content "You will receive an email with instructions on how to reset your password in a few minutes."
  end
  scenario "not happy path email" do
    Fabricate(:user, email: "adam@example.com")
    visit '/'
    click_link "Sign in"
    click_link "Forgot your password?"
    fill_in "user_email", with: "not-adam@example.com"
    click_button "Send me reset password instructions"
    page.should have_content "not found"
  end
end
