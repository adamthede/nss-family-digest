class AnswersController < ApplicationController

  def create_from_form
    answer = Answer.create do |answer|
      answer.answer = params[:answer]
      answer.user_id = params[:user_id]
      answer.question_record_id = params[:question_record_id]
    end
    redirect_to question_record_path(params[:question_record_id]), notice: "Your answer has been submitted!"
  end

end
