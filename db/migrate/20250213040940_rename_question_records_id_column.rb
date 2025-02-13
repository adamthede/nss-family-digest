class RenameQuestionRecordsIdColumn < ActiveRecord::Migration[8.0]
  def change
    rename_column :answers, :question_records_id, :question_record_id
  end
end