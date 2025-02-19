class Tag < ApplicationRecord
  has_many :question_tags, dependent: :destroy
  has_many :questions, through: :question_tags

  has_many :group_question_tags, dependent: :destroy
  has_many :groups, through: :group_question_tags

  validates :name, presence: true, uniqueness: { case_sensitive: false }
end