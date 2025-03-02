class QuestionRecord < ApplicationRecord
  belongs_to :group
  belongs_to :question
  belongs_to :question_digest, optional: true
  has_many :answers, dependent: :destroy

  validates :group_id, presence: true
  validates :question_id, presence: true

  # Scopes
  scope :with_digest, -> { where.not(question_digest_id: nil) }
  scope :without_digest, -> { where(question_digest_id: nil) }
  scope :in_period, ->(start_date, end_date) { where(created_at: start_date.beginning_of_day..end_date.end_of_day) }

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
