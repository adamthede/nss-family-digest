class AddTimestampsToMemberships < ActiveRecord::Migration[7.0]
  def change
    add_timestamps :memberships, null: false, default: -> { 'CURRENT_TIMESTAMP' }

    # After adding timestamps with defaults, remove the defaults
    change_column_default :memberships, :created_at, from: -> { 'CURRENT_TIMESTAMP' }, to: nil
    change_column_default :memberships, :updated_at, from: -> { 'CURRENT_TIMESTAMP' }, to: nil
  end
end