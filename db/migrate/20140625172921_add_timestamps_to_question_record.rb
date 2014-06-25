class AddTimestampsToQuestionRecord < ActiveRecord::Migration
  def change
    change_table :question_records do |t|
      t.timestamps
    end
  end
end
