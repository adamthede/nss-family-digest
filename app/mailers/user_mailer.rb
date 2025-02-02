class UserMailer < ApplicationMailer
  layout 'mail_layout'
  default from: ENV['DEFAULT_MAILER_FROM']

  def welcome_email(user)
    @user = user
    @url = root_url
    mail(to: @user.email, subject: "Welcome to Answers 2 Answers")
  end

  def confirmation_email(user)
    @user = user
    @url = root_url
    mail(to: @user.email, subject: "Your Password Has Been Changed")
  end
end
