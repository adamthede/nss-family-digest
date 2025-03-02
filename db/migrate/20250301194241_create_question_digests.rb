class CreateQuestionDigests < ActiveRecord::Migration[8.0]
  def change
    create_table :question_digests do |t|
      t.references :group, null: false, foreign_key: true
      t.date :start_date
      t.date :end_date
      t.string :status
      t.datetime :sent_at

      t.timestamps
    end
  end
end
