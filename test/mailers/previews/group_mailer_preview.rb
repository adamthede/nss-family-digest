# Preview all emails at http://localhost:3000/rails/mailers/group_mailer
class GroupMailerPreview < ActionMailer::Preview
  include ActiveRecord::TestFixtures

  def invite_email
    # Create or find a sample group
    group = Group.first_or_create!(
      name: 'Preview Group',
      description: 'A sample group for preview'
    )

    # Create or find a sample user
    user = User.find_or_create_by_email('preview@example.com')

    # Create a sample membership with invitation token
    membership = group.memberships.create!(
      user: user,
      active: false,
      invitation_token: SecureRandom.urlsafe_base64(32)
    )

    # Preview both scenarios - new and existing users
    [
      # New user preview
      GroupMailer.invite_email(user.email, group.id, membership.invitation_token),

      # Existing user preview (with password)
      GroupMailer.invite_email(
        User.find_or_create_by_email('existing@example.com') { |u|
          u.password = 'password123'
        }.email,
        group.id,
        membership.invitation_token
      )
    ].first # Return first preview, but both are available via the preview interface
  end

  def invite_email_new_user
    ActiveRecord::Base.transaction do
      preview_invitation(new_user: true).tap do
        raise ActiveRecord::Rollback # Rollback all changes after preview
      end
    end
  end

  def invite_email_existing_user
    ActiveRecord::Base.transaction do
      preview_invitation(new_user: false).tap do
        raise ActiveRecord::Rollback # Rollback all changes after preview
      end
    end
  end

  private

  def preview_invitation(new_user: true)
    ActiveRecord::Base.transaction do
      # Create temporary data for preview
      group = Group.new(
        name: 'Preview Group',
        description: 'A sample group for preview'
      )
      group.save(validate: false)

      email = new_user ? 'new@example.com' : 'existing@example.com'
      user = User.new(email: email)
      user.save(validate: false)

      # Set password for existing user preview
      user.update_column(:encrypted_password, 'dummy') unless new_user

      membership = Membership.new(
        user: user,
        group: group,
        active: false,
        invitation_token: SecureRandom.urlsafe_base64(32)
      )
      membership.save(validate: false)

      # Generate preview
      mail = GroupMailer.invite_email(user.email, group.id, membership.invitation_token)

      raise ActiveRecord::Rollback # Rollback all changes

      mail # Return the mail object for preview
    end
  end
end