class StartsController < ApplicationController
  def start_questions
    users = Group.find(params[:group_id]).users
    emails = []
    users.each do |user|
      emails << user.email
    end
    QuestionMailer.send_questions(emails, params[:group_id]).deliver
    redirect_to group_path(params[:group_id]), notice: "The questioning has begun!"
  end
end
