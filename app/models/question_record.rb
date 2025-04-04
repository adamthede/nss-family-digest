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
  # Retrieves the next QuestionRecord for the same group that was created after the current record.
  #
  # This method queries the associated question records for the group, filtering for those with a
  # creation timestamp greater than that of the current record, orders them in ascending order by creation time,
  # and returns the first record found.
  #
  # @return [QuestionRecord, nil] the next digest or nil if no subsequent record exists
  def next_digest
    group.question_records
         .where('created_at > ?', created_at)
         .order(created_at: :asc)
         .first
  end

  ##
  # Retrieves the previous digest record for the current group.
  #
  # It queries the group's question records for those created before the current record's timestamp,
  # orders them in descending order by creation time, and returns the first record found.
  #
  # @return [QuestionRecord, nil] the previous digest record if it exists, otherwise nil
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
