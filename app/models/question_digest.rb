class QuestionDigest < ApplicationRecord
  belongs_to :group
  has_many :question_records, dependent: :nullify

  # Define statuses
  STATUSES = %w[pending processing sent failed].freeze

  # Validations
  validates :group_id, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :status, inclusion: { in: STATUSES }

  # Default values
  after_initialize :set_defaults, if: :new_record?

  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :sent, -> { where(status: 'sent') }
  scope :for_period, ->(start_date, end_date) { where('start_date >= ? AND end_date <= ?', start_date, end_date) }

  # Helper methods
  def questions
    Question.where(id: question_records.pluck(:question_id))
  end

  def answers
    Answer.where(question_record_id: question_records.pluck(:id))
  end

  def pending?
    status == 'pending'
  end

  def sent?
    status == 'sent'
  end

  def mark_as_sent!
    update!(status: 'sent', sent_at: Time.current)
  end

  def mark_as_failed!
    update!(status: 'failed')
  end

  def next_digest
    group.question_digests
         .where('start_date > ?', end_date)
         .order(start_date: :asc)
         .first
  end

  def previous_digest
    group.question_digests
         .where('end_date < ?', start_date)
         .order(end_date: :desc)
         .first
  end

  private

  def set_defaults
    self.status ||= 'pending'
  end
end
