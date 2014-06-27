class UserMailer < ActionMailer::Base
  layout 'mail_layout'
  default from: "adam@thedetech.com"

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
