require 'spec_helper'

feature "user views all questions" do
  scenario "view index page of questions" do
    User.create(email: "adam@example.com", password: "password", password_confirmation: "password")
    visit "/"
    click_link "Sign in"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Questions"
    click_link "New Question"
    fill_in "Question", with: "What is your favorite programming language?"
    click_button "Add Question"
    click_link "Questions"

    page.should have_content "Listing questions"
    page.should have_content "What is your favorite programming language?"
  end
end
