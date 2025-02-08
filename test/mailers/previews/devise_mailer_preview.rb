# Preview all emails at http://localhost:3000/rails/mailers/devise_mailer
class DeviseMailerPreview < ActionMailer::Preview
  include Rails.application.routes.url_helpers

  def reset_password_instructions
    Devise::Mailer.reset_password_instructions(preview_user, "faketoken123")
  end

  private

  def preview_user
    User.first_or_create!(
      email: 'preview@example.com',
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  def default_url_options
    Rails.application.config.action_mailer.default_url_options || { host: 'localhost', port: 3000 }
  end
end