# Preview all emails at http://localhost:3000/rails/mailers/group_mailer
class GroupMailerPreview < ActionMailer::Preview
  def invite_email
    group = Group.first_or_create!(
      name: 'Preview Group',
      description: 'A sample group for preview'
    )

    GroupMailer.invite_email('preview@example.com', group.id)
  end
end