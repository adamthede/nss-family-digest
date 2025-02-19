class CreateGroupQuestionTags < ActiveRecord::Migration[8.0]
  def change
    create_table :group_question_tags do |t|
      t.references :group, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :group_question_tags, [:group_id, :question_id, :tag_id], unique: true, name: 'idx_group_question_tags_unique'
  end
end
