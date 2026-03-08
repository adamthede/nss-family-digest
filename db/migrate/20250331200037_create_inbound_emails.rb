class CreateInboundEmails < ActiveRecord::Migration[8.0]
  ##
  # Creates the inbound_emails table with its defined columns and index.
  #
  # This migration establishes a new inbound_emails table including:
  # - payload: a text column for storing the raw email content.
  # - status: a string column that tracks the current processing state.
  # - processor_notes: a text column for related processing information.
  # - processed_at: a datetime column indicating when the email was processed.
  # - answer: a nullable reference column linked to an answer record with a foreign key constraint.
  #
  # Additionally, timestamp columns (created_at and updated_at) are automatically added, and
  # an index is created on the status column to enhance query performance.
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
