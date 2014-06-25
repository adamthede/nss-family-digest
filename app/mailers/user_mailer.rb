class UserMailer < ActionMailer::Base
  layout 'mail_layout'
  default from: "adam@thedetech.com"

  def welcome_email(user)
    @user = user
    @url = root_url
    # @url = "http://familydigest.herokuapp.com"
    mail(to: @user.email, subject:"Welcome to Family Digest")
  end

  def confirmation_email(user)
    @user = user
    @url = root_url
    mail(to: @user.email, subject:"Your Password Has Been Changed")
  end
end
