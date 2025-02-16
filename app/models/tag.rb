class Tag < ApplicationRecord
  has_many :question_tags, dependent: :destroy
  has_many :questions, through: :question_tags

  validates :name, presence: true, uniqueness: true
end