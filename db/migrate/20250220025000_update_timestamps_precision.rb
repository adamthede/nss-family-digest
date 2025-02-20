class UpdateTimestampsPrecision < ActiveRecord::Migration[7.0]
  def change
    # Update answers timestamps
    change_column :answers, :created_at, :datetime, precision: 6
    change_column :answers, :updated_at, :datetime, precision: 6

    # Update groups timestamps
    change_column :groups, :created_at, :datetime, precision: 6
    change_column :groups, :updated_at, :datetime, precision: 6

    # Update question_records timestamps
    change_column :question_records, :created_at, :datetime, precision: 6
    change_column :question_records, :updated_at, :datetime, precision: 6

    # Update questions timestamps
    change_column :questions, :created_at, :datetime, precision: 6
    change_column :questions, :updated_at, :datetime, precision: 6
  end
end