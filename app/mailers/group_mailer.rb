class GroupMailer < ActionMailer::Base
  default from: "from@example.com"

  def invite_email(emails, group_id)
    @group_id = group_id
    mail(to: emails, subject: "You've been invited to join a group!", host: 'example.com')
  end
end
