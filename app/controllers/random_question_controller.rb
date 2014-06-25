class RandomQuestionController < ApplicationController
  def send_random_question
    users = Group.find(params[:group_id]).users
    emails = []
    users.each do |user|
      emails << user.email
    end
    QuestionMailer.send_questions(emails, params[:group_id]).deliver
    redirect_to group_path(params[:group_id]), notice: "Random question sent!"
  end
end
