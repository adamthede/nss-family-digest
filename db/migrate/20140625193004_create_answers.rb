class CreateAnswers < ActiveRecord::Migration
  def change
    create_table :answers do |t|
      t.string :answer
      t.integer :question_records_id
      t.integer :user_id

      t.timestamps
    end
  end
end
