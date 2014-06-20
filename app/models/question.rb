class Question < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :groups

  validates_presence_of :question
  validates_presence_of :user
end
