# Preview all emails at http://localhost:3000/rails/mailers/admin_notification_mailer
class AdminNotificationMailerPreview < ActionMailer::Preview
  def new_signup
    # Create a test user
    test_user = User.create!(
      email: "preview_signup_#{Time.now.to_i}@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    # Generate the preview
    preview = AdminNotificationMailer.new_signup(test_user)

    # Clean up the test user after preview is generated
    test_user.destroy

    preview
  end

  # Add similar methods for other mailer actions
end