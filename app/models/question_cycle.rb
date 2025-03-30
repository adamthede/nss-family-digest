class QuestionCycle < ApplicationRecord
  belongs_to :group
  belongs_to :question
  belongs_to :question_record, optional: true

  # Updated enum definition with correct options for Rails 8
  enum :status, { scheduled: 0, active: 1, closed: 2, completed: 3 }, suffix: true

  # Helper method for status comparisons
  def status?(value)
    case value
    when Integer
      # Compare with integer directly
      status.to_i == value
    when String, Symbol
      # Compare string representation with the status
      status.to_s == value.to_s
    else
      false
    end
  end

  validates :start_date, :end_date, :digest_date, presence: true

  # Ensure proper date sequence
  validate :date_sequence_valid

  # Find cycles that should be activated today
  scope :activate_today, -> { where(status: :scheduled, start_date: Date.current) }

  # Find cycles that should be closed today
  scope :close_today, -> { where(status: :active, end_date: Date.current) }

  # Find cycles ready for digest today
  scope :digest_today, -> { where(status: :closed, digest_date: Date.current) }

  # Filter by manual/auto
  scope :automatic, -> { where(manual: false) }
  scope :manual, -> { where(manual: true) }

  def activate!
    # Create question record if not exists
    unless question_record
      record = QuestionRecord.create!(group: group, question: question)
      update!(question_record: record)
    end

    update!(status: :active)
  end

  def close!
    update!(status: :closed)
  end

  def complete!
    update!(status: :completed)
  end

  def remaining_days
    return 0 unless status?(1) || status?("active")
    (end_date - Date.current).to_i
  end

  def answer_count
    question_record&.answers&.count || 0
  end

  private

  def date_sequence_valid
    return unless start_date && end_date && digest_date

    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end

    if digest_date <= end_date
      errors.add(:digest_date, "must be after end date")
    end
  end
end