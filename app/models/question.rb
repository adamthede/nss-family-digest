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

  def self.send_question
    question = Question.select_random_question
    Group.all.each do |group|
      Group.add_question_to_group(group, question)
      group.users.each do |user|
        QuestionMailer.weekly_question(user, group, question).deliver
      end
    end
  end

  def self.select_random_question
    Question.offset(rand(Question.count)).first
  end

end
