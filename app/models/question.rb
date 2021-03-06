class Question < ActiveRecord::Base
  belongs_to :user
  has_many :groups, through: :question_record

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
