class Question < ApplicationRecord
  belongs_to :user
  has_many :question_records
  has_many :groups, through: :question_records

  # Tag associations
  has_many :question_tags, dependent: :destroy
  has_many :tags, through: :question_tags  # These are the global tags

  has_many :group_question_tags, dependent: :destroy
  has_many :group_tags, through: :group_question_tags, source: :tag  # These are the group-specific tags

  validates_presence_of :question
  validates_presence_of :user

  scope :with_usage_in_group, ->(group) {
    left_joins(:question_records)
      .where(question_records: { group_id: group.id })
      .group(:id)
      .select('questions.*, COUNT(question_records.id) as usage_count')
  }

  scope :with_votes_in_group, ->(group) {
    left_joins(group_questions: :group_question_votes)
      .where(group_questions: { group_id: group.id })
      .group(:id)
      .select('questions.*, COUNT(group_question_votes.id) as vote_count')
  }

  scope :filter_by_tag, ->(tag_id, group_id) {
    where(
      'questions.id IN (SELECT question_id FROM question_tags WHERE tag_id = ?) OR ' \
      'questions.id IN (SELECT question_id FROM group_question_tags WHERE tag_id = ? AND group_id = ?)',
      tag_id, tag_id, group_id
    )
  }

  scope :filter_by_usage, ->(group, status) {
    case status
    when 'used'
      joins(:question_records).where(question_records: { group_id: group.id }).distinct
    when 'unused'
      where.not(id: QuestionRecord.where(group_id: group.id).select(:question_id))
    else
      all
    end
  }

  def self.select_random_question(group = nil)
    base_query = Question.all

    if group
      # Start with questions available to this group
      available = group.available_questions

      # Exclude questions that have been used in this group
      unused = available.where.not(id: group.recorded_questions.pluck(:id))

      if unused.exists?
        # Prioritize unused questions
        base_query = unused
      else
        # If all questions have been used, reset and use all available questions
        base_query = available
      end
    end

    # Ensure we have questions to choose from
    return nil unless base_query.exists?

    # Add some randomization logic
    # First try questions that haven't been used much
    less_used = base_query
      .left_joins(:question_records)
      .group('questions.id')
      .having('COUNT(question_records.id) <= 3')

    if less_used.exists?
      less_used.order('RANDOM()').first
    else
      # Fall back to completely random if all questions have been used a lot
      base_query.order('RANDOM()').first
    end
  end

  # Find questions that haven't been sent to this group within the specified period
  def self.not_sent_to_group_in_period(group, start_date, end_date)
    sent_question_ids = QuestionRecord.where(group: group)
                                     .in_period(start_date, end_date)
                                     .pluck(:question_id)

    where.not(id: sent_question_ids)
  end

  # Find questions that haven't been sent to this group ever
  def self.never_sent_to_group(group)
    sent_question_ids = QuestionRecord.where(group: group).pluck(:question_id)
    where.not(id: sent_question_ids)
  end

end
