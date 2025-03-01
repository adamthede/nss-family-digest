class AdminNotificationMailer < ApplicationMailer
  def new_user_signup(user)
    @user = user
    mail(
      to: ENV['DEFAULT_MAILER_FROM'],
      subject: "New User Signup: #{@user.email}"
    )
  end
end