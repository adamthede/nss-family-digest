class QuestionRecordsController < ApplicationController
  before_action :set_question_record, only: [:show]

  def show
    @group = Group.find(@question_record.group_id)
    @question = Question.find(@question_record.question_id)
    @answers = Answer.where(question_record_id: @question_record.id)
    @next_digest = @question_record.next_digest
    @previous_digest = @question_record.previous_digest
  end

  private

  def set_question_record
    @question_record = QuestionRecord.find(params[:id])
  end

end
