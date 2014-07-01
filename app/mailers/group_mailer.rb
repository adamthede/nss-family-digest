class GroupMailer < ActionMailer::Base
  default from: "adam@thedetech.com"
  default reply_to: ENV['POSTMARK_INBOUND']
  layout 'mail_layout'

  def invite_email(emails, group_id)
    @group_id = group_id
    mail(to: emails, subject: "You've been invited to join a group!")
  end
end
