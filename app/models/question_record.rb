class QuestionRecord < ApplicationRecord
  belongs_to :group
  belongs_to :question
  has_many :answers, dependent: :destroy

  validates :group_id, presence: true
  validates :question_id, presence: true

  def next_digest
    group.question_records
         .where('created_at > ?', created_at)
         .order(created_at: :asc)
         .first
  end

  def previous_digest
    group.question_records
         .where('created_at < ?', created_at)
         .order(created_at: :desc)
         .first
  end
end
