class GroupMailer < ApplicationMailer
  default from: "adam@thedetech.com"
  default reply_to: ENV['POSTMARK_INBOUND']
  layout 'mail_layout'

  def invite_email(email, group_id)
    @group_id = group_id
    @email = email
    mail(to: email, subject: "You've been invited to join a group!")
  end
end
