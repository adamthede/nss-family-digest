class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :group

  validates :user_id, uniqueness: { scope: :group_id,
    message: "is already a member of this group" }

  scope :active, -> { where(active: true) }
  scope :inactive, -> { where(active: false) }
  scope :pending, -> { where(active: false, invitation_accepted_at: nil) }

  before_create :generate_invitation_token

  def activate!
    update!(active: true)
  end

  def deactivate!
    update!(active: false)
  end

  def toggle_active!
    update!(active: !active)
  end

  def accept_invitation!
    update!(
      active: true,
      invitation_accepted_at: Time.current,
      invitation_token: nil
    )
  end

  def pending?
    !active? && invitation_accepted_at.nil?
  end

  private

  def generate_invitation_token
    self.invitation_token = SecureRandom.urlsafe_base64(32)
  end
end
