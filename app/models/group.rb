class Group < ActiveRecord::Base
  belongs_to :leader, :class_name => :User, :foreign_key => 'user_id'
  has_many :questions
  has_many :memberships, dependent: :destroy
  has_many :users, through: :memberships

  validates_presence_of :leader
end
