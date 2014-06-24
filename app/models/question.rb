class Question < ActiveRecord::Base
  belongs_to :user
  has_many :groups

  validates_presence_of :question
  validates_presence_of :user
end
