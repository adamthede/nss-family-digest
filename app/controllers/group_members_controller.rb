class GroupMembersController < ApplicationController
  before_action :set_group
  before_action :set_member

  def show
    @answers = Answer.joins(:question_record)
                    .where(user_id: @member.id)
                    .where(question_records: { group_id: @group.id })
                    .order('question_records.created_at DESC')
    @questions = Question.where(id: @answers.map(&:question_record).map(&:question_id))
                        .index_by(&:id)
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def set_member
    @member = User.find(params[:id])
  end
end