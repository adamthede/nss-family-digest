class CreateGroupQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :group_questions do |t|
      t.references :group, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true

      t.timestamps
    end

    add_index :group_questions, [:group_id, :question_id], unique: true
  end
end
