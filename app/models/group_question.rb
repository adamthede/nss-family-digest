class GroupQuestion < ApplicationRecord
  belongs_to :group
  belongs_to :question

  has_many :group_question_votes, dependent: :destroy

  # Helper method to count votes
  def vote_count
    group_question_votes.count
  end

  validates :question_id, uniqueness: { scope: :group_id }
end