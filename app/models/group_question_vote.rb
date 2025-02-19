class GroupQuestionVote < ApplicationRecord
  belongs_to :group_question
  belongs_to :user

  validates :user_id, uniqueness: { scope: :group_question_id }
end