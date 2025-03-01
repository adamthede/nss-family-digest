class AdminNotificationMailer < ApplicationMailer
  def new_user_signup(user)
    @user = user
    mail(
      to: "your-email@example.com",
      subject: "New User Signup: #{@user.email}"
    )
  end
end