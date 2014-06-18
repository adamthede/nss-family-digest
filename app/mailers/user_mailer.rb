class UserMailer < ActionMailer::Base
  default from: "from@example.com"

  def welcome_email(user)
    @user = user
    @url = "http://familydigest.herokuapp.com"
    mail(to:@user.email, subject:"Welcome to Family Digest")
  end
end
