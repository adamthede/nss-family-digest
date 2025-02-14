class AddGlobalAdminToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :global_admin, :boolean, default: false, null: false

    add_index :users, :global_admin,
              unique: true,
              where: "global_admin = true",
              name: "index_users_on_global_admin"
  end

  def down
    remove_index :users, name: "index_users_on_global_admin"
    remove_column :users, :global_admin
  end
end
