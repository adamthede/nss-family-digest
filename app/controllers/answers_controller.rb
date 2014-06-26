class AnswersController < ApplicationController

  def create_from_form
    answer = Answer.create do |answer|
      answer.answer = params[:answer]
      answer.user_id = params[:user_id]
      answer.question_records_id = params[:question_records_id]
    end
    redirect_to question_record_path(params[:question_records_id]), notice: "Your answer has been submitted!"
  end
  
end
