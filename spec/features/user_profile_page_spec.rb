require 'spec_helper'

feature "User visits profile page" do
  let!(:adam) { Fabricate(:user, email: "adam@cityofthedes.com") }
  let!(:nat) { Fabricate(:user, email: "nat@example.com") }

  scenario "User visits own profile page" do
    login_as adam
    visit user_path(adam)
    page.should have_content "adam@cityofthedes.com"
    page.should have_content "This is your profile"
  end

  scenario "User visits someone elses profile page" do
    login_as adam
    visit user_path(nat)
    page.should have_content "nat@example.com"
    page.should_not have_content "adam@cityofthedes.com"
  end

  scenario "user not logged in" do
    visit user_path(nat)
    page.should have_content "nat@example.com"
    page.should_not have_content "adam@cityofthedes.com"
    page.should_not have_content "This is your profile"
  end
end
