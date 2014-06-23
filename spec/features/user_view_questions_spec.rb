require 'spec_helper'

feature "user views all questions" do
  scenario "view index page of questions" do
    Fabricate(:user, email: "adam@example.com")
    Fabricate(:question, question: "What did you do today?")
    visit root_path
    click_link "Sign in"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Questions"
    click_link "New Question"
    fill_in "Question", with: "What is your favorite programming language?"
    click_button "Add Question"
    click_link "Questions"

    page.should have_content "Questions"
    page.should have_content "What is your favorite programming language?"
    page.should have_content "What did you do today?"
  end
end
