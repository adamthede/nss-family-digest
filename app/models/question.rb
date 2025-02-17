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
