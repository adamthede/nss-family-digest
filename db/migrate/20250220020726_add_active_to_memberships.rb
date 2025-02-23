class AddActiveToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :active, :boolean, default: false, null: false
    add_column :memberships, :invitation_accepted_at, :datetime
    add_column :memberships, :invitation_token, :string
    add_index :memberships, :active
    add_index :memberships, :invitation_token, unique: true
  end
end
