class AddPerformanceIndexes < ActiveRecord::Migration[8.0]
  def change
    unless index_exists?(:group_questions, [:group_id, :question_id])
      add_index :group_questions, [:group_id, :question_id]
    end

    unless index_exists?(:group_question_votes, [:group_question_id, :user_id])
      add_index :group_question_votes, [:group_question_id, :user_id]
    end

    unless index_exists?(:question_records, [:group_id, :question_id])
      add_index :question_records, [:group_id, :question_id]
    end

    unless index_exists?(:answers, [:question_record_id, :user_id])
      add_index :answers, [:question_record_id, :user_id]
    end

    unless index_exists?(:group_question_tags, [:group_id, :tag_id])
      add_index :group_question_tags, [:group_id, :tag_id]
    end
  end
end
