class CreateGroupQuestionVotes < ActiveRecord::Migration[8.0]
  def change
    create_table :group_question_votes do |t|
      t.references :group_question, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    # A user should cast only one vote per group/question association
    add_index :group_question_votes, [:group_question_id, :user_id], unique: true
  end
end
