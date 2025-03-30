class SetQuestionModeDefaults < ActiveRecord::Migration[6.1]
  def up
    # Set default question_mode for all existing groups
    execute <<-SQL
      UPDATE groups SET question_mode = 'automatic' WHERE question_mode IS NULL
    SQL
  end

  def down
    # Nothing to do for rollback
  end
end