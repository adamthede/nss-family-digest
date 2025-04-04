class QuestionCycle < ApplicationRecord
  belongs_to :group
  belongs_to :question
  belongs_to :question_record, optional: true

  # Updated enum definition with correct options for Rails 8
  enum :status, { scheduled: 0, active: 1, closed: 2, completed: 3 }, suffix: true

  ##
  # Checks if the current status matches the provided value.
  #
  # The method flexibly compares the object's status with a given value, handling both numerical and string representations.
  # If an Integer is provided, it compares directly with the status converted to an integer.
  # If a String or Symbol is provided, it compares with the string representation of the status.
  #
  # @param value [Integer, String, Symbol] the value to match against the current status
  # @return [Boolean] true if the provided value corresponds to the current status, false otherwise
  #
  # @example Compare with an integer value
  #   status?(1)
  #
  # @example Compare with a string value
  #   status?("active")
  #
  # @example Compare with a symbol
  #   status?(:active)
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

  ##
  # Checks if the question cycle is active.
  #
  # This convenience method wraps the underlying status check, providing an intuitive
  # interface for determining if the cycle's current status is active.
  #
  # @return [Boolean] true if the question cycle is active, false otherwise.
  def active?
    status_active?
  end

  ##
  # Determines if the question cycle is marked as closed.
  #
  # @return [Boolean] True if the cycle's status is closed, false otherwise.
  def closed?
    status_closed?
  end

  ##
  # Determines if the question cycle is scheduled.
  #
  # @return [Boolean] true if the cycle's status is scheduled, false otherwise.
  def scheduled?
    status_scheduled?
  end

  ##
  # Returns true if the question cycle is marked as completed.
  #
  # This is a convenience method that delegates to +status_completed?+.
  #
  # @return [Boolean] true if the cycle's status is completed, false otherwise.
  def completed?
    status_completed?
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