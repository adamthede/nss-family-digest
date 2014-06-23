class GroupMembership < ActiveRecord::Base
  has_many :users, through :groups, foreign_key: 'user_id'
  has_many :groups, foreign_key: 'group_id'
end
