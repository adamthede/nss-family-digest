class AddGlobalAndCategoryToQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :questions, :global, :boolean, default: false, null: false
    add_column :questions, :category, :string
  end
end
