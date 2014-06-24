class AddLeaderIdToGroup < ActiveRecord::Migration
  def change
    add_column :groups, :leader_id, :string
  end
end
