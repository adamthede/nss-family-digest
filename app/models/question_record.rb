class QuestionRecord < ApplicationRecord
  belongs_to :question
  belongs_to :group

  def next_digest
    group.question_records
         .where('created_at > ?', created_at)
         .order(created_at: :asc)
         .first
  end

  def previous_digest
    group.question_records
         .where('created_at < ?', created_at)
         .order(created_at: :desc)
         .first
  end
end
