class InvitesController < ApplicationController
  def send_invite
    GroupMailer.invite_email(params[:emails], params[:group_id]).deliver_now
    redirect_to group_path(params[:group_id]), notice: "Your invites have been sent!"
  end
end
