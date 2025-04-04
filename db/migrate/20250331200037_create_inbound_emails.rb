class CreateInboundEmails < ActiveRecord::Migration[8.0]
  ##
  # Creates the inbound_emails table used to store email details.
  #
  # This migration defines a table with the following columns:
  # - payload: Stores the text content of the email.
  # - status: Indicates the processing status.
  # - processor_notes: Contains any notes added by a processor.
  # - processed_at: Records when the email was processed.
  # - answer: An optional foreign key reference linking to an associated answer.
  #
  # Timestamps for record creation and updates are automatically added,
  # and an index is created on the status column to improve query performance.
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
