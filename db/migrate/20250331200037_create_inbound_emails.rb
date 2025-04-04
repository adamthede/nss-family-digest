class CreateInboundEmails < ActiveRecord::Migration[8.0]
  ##
  # Creates the inbound_emails table used for storing inbound email details.
  #
  # The migration defines the following columns:
  # - payload (text) for the email content
  # - status (string) for indicating the email state
  # - processor_notes (text) for any additional processing notes
  # - processed_at (datetime) to record when the email was handled
  # - answer (reference) as an optional association to an answer record via a foreign key
  #
  # It also adds automatic timestamp columns (created_at and updated_at) and an index on the status column to enhance lookup performance.
  def change
    create_table :inbound_emails do |t|
      t.text :payload
      t.string :status
      t.text :processor_notes
      t.datetime :processed_at
      t.references :answer, null: true, foreign_key: true

      t.timestamps
    end
    add_index :inbound_emails, :status
  end
end
