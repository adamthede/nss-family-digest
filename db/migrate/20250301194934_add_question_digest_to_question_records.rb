class AddQuestionDigestToQuestionRecords < ActiveRecord::Migration[8.0]
  def change
    add_reference :question_records, :question_digest, null: true, foreign_key: true
  end
end
