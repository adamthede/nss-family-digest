class QuestionRecord < ApplicationRecord
  belongs_to :question
  belongs_to :group
end
