class AddUniqueIndexToMemberships < ActiveRecord::Migration[7.0]
  def change
    # Remove any duplicate memberships before adding the constraint
    duplicates = Membership.select(:user_id, :group_id)
      .group(:user_id, :group_id)
      .having('count(*) > 1')

    duplicates.each do |duplicate|
      memberships = Membership.where(
        user_id: duplicate.user_id,
        group_id: duplicate.group_id
      )

      # Keep one membership (the first one) and delete others
      memberships_to_remove = memberships.offset(1)
      memberships_to_remove.destroy_all
    end

    add_index :memberships, [:user_id, :group_id], unique: true
  end
end
