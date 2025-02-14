class Group < ApplicationRecord
  belongs_to :leader, :class_name => :User, :foreign_key => 'user_id'
  has_many :question_records
  has_many :questions, through: :question_records
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  validates_presence_of :leader

  def self.add_question_to_group(group, question)
    group.questions << question
  end

end
