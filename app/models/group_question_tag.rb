class GroupQuestionTag < ApplicationRecord
  belongs_to :group
  belongs_to :question
  belongs_to :tag
  belongs_to :created_by, class_name: 'User'
end