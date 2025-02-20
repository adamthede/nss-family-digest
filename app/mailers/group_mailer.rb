class GroupMailer < ApplicationMailer
  default reply_to: ENV['SENDGRID_INBOUND']
  layout 'mail_layout'

  include Rails.application.routes.url_helpers

  def invite_email(email, group_id, invitation_token)
    @user = User.find_by(email: email)
    @group = Group.find(group_id)
    @invitation_token = invitation_token
    @accept_url = accept_invitation_groups_url(token: @invitation_token)

    mail(
      to: email,
      subject: "You've been invited to join #{@group.name}"
    )
  end
end
