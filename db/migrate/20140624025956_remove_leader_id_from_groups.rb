class RemoveLeaderIdFromGroups < ActiveRecord::Migration
  def change
    remove_column :groups, :leader_id, :string
  end
end
