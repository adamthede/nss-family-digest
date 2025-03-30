class CreateQuestionCycles < ActiveRecord::Migration[8.0]
  def change
    create_table :question_cycles do |t|
      t.references :group, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.references :question_record, foreign_key: true
      t.date :start_date
      t.date :end_date
      t.date :digest_date
      t.integer :status, default: 0
      t.boolean :manual, default: false

      t.timestamps
    end
  end
end