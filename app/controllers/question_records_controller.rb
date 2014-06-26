class QuestionRecordsController < ApplicationController
  before_action :set_question_record, only: [:show, :edit, :update, :destroy]

  def show
    @group = Group.find(@question_record.group_id)
    @question = Question.find(@question_record.question_id)
    @answers = Answer.where(question_records_id: @question_record.id)
  end

  private

  def set_question_record
    @question_record = QuestionRecord.find(params[:id])
  end

end
