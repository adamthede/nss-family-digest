class AddQuestionCycleControlToGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :groups, :question_mode, :string, default: 'automatic'
    add_column :groups, :paused_until, :date
  end
end
