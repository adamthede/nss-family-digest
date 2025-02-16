class Group < ApplicationRecord
  belongs_to :leader, :class_name => :User, :foreign_key => 'user_id'
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  # Primary association for bank/available questions through group_questions
  has_many :group_questions, dependent: :destroy
  has_many :available_questions, through: :group_questions, source: :question

  # Existing associations for historical/answered questions
  has_many :question_records
  has_many :questions, through: :question_records  # Original association
  has_many :recorded_questions, through: :question_records, source: :question  # Alias for clarity

  validates_presence_of :leader

  def self.add_question_to_group(group, question)
    group.group_questions.create!(question: question)
  end

end
