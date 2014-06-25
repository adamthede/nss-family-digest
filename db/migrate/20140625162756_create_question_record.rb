class CreateQuestionRecord < ActiveRecord::Migration
  def change
    create_table :question_records do |t|
      t.integer :question_id
      t.integer :group_id
    end
  end
end
