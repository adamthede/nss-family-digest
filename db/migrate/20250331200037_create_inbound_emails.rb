class CreateInboundEmails < ActiveRecord::Migration[8.0]
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
