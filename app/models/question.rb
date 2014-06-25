class Question < ActiveRecord::Base
  belongs_to :user
  has_many :groups

  validates_presence_of :question
  validates_presence_of :user

  def self.send_question
    Group.all.each do |group|
      group.users.each do |user|
        QuestionMailer.weekly_question(user, group).deliver
      end
    end
  end
end
