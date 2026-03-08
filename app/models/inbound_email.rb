class InboundEmail < ApplicationRecord
  belongs_to :answer, optional: true

  # Store payload as a Hash
  serialize :payload, Hash

  # Statuses: received, processing, processed, failed
  validates :status, presence: true, inclusion: { in: %w[received processing processed failed] }
end
