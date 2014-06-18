require 'spec_helper'

feature "User creates new question" do
  scenario "successful new question" do
    User.create(email: "adam@example.com", password: "password", password_confirmation: "password")
    visit "/"
    click_link "Sign in"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Questions"
    click_link "New Question"
    fill_in "Question", with: "This is a sample question, ya dig?"
    click_button "Add Question"
    page.should have_content "Question was successfully created."
  end

  scenario "failed new question (no question entered)" do
    User.create(email: "adam@example.com", password: "password", password_confirmation: "password")
    visit "/"
    click_link "Sign in"
    fill_in "Email", with: "adam@example.com"
    fill_in "Password", with: "password"
    click_button "Sign in"
    click_link "Questions"
    click_link "New Question"
    click_button "Add Question"
    page.should have_content "can't be blank"
  end
end