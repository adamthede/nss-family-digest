class QuestionRecord < ApplicationRecord
  belongs_to :group
  belongs_to :question
  has_many :answers, dependent: :destroy

  validates :group_id, presence: true
  validates :question_id, presence: true

  # Scope to find records with active cycles that are accepting answers
  scope :accepting_answers, -> {
    joins("LEFT JOIN question_cycles ON question_cycles.question_record_id = question_records.id")
    .where("question_cycles.status = 1") # Active status
  }

  # Scope to find the most recent record for a group/question combination
  scope :most_recent_for, ->(group_id, question_id) {
    where(group_id: group_id, question_id: question_id)
    .order(created_at: :desc)
    .limit(1)
  }

  ##
  # Retrieves the next QuestionRecord within the same group that was created after this record.
  #
  # This method returns the first record, ordered by creation time in ascending order,
  # that has a created_at timestamp greater than that of the current record.
  #
  # @return [QuestionRecord, nil] The next QuestionRecord in the group's sequence, or nil if none exists.
  def next_digest
    group.question_records
         .where('created_at > ?', created_at)
         .order(created_at: :asc)
         .first
  end

  ##
  # Returns the previous QuestionRecord (digest) in the same group.
  #
  # This method retrieves the most recent record belonging to the same group that was created
  # before the current record's timestamp. If no prior record exists, it returns nil.
  #
  # @return [QuestionRecord, nil] the previous digest if found, otherwise nil.
  def previous_digest
    group.question_records
         .where('created_at < ?', created_at)
         .order(created_at: :desc)
         .first
  end

  # Find active/answerable record for a given group and question
  def self.find_active_record(group_id, question_id)
    accepting_answers
      .where(group_id: group_id, question_id: question_id)
      .order(created_at: :desc)
      .first
  end
end
