class GroupQuestion < ApplicationRecord
  belongs_to :group
  belongs_to :question

  has_many :group_question_votes, dependent: :destroy
  has_many :voting_users, through: :group_question_votes, source: :user

  # Helper method to count votes
  def vote_count
    group_question_votes.count
  end

  # Helper method to check if a user has voted
  def voted_by?(user)
    group_question_votes.exists?(user: user)
  end

  validates :question_id, uniqueness: { scope: :group_id }
end