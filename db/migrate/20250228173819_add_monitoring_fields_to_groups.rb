class AddMonitoringFieldsToGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :groups, :last_activity_at, :datetime
    add_column :groups, :plan, :string, default: 'free'
    add_column :groups, :storage_used, :integer, default: 0
    add_column :memberships, :last_active_at, :datetime
  end
end
