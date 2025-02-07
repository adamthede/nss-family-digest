# Preview all emails at http://localhost:3000/rails/mailers/user_mailer
class UserMailerPreview < ActionMailer::Preview
  def welcome_email
    user = User.first_or_create!(
      email: 'preview@example.com',
      password: 'password123456789',
      password_confirmation: 'password123456789'
    )

    UserMailer.welcome_email(user)
  end

  def confirmation_email
    user = User.first_or_create!(
      email: 'preview@example.com',
      password: 'password123456789',
      password_confirmation: 'password123456789'
    )

    UserMailer.confirmation_email(user)
  end
end