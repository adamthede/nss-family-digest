class DigestMailer < ApplicationMailer
  def weekly_digest(user, digest)
    @user = user
    @digest = digest
    @group = digest.group
    @question_records = digest.question_records.includes(:question, answers: :user)

    mail(
      to: @user.email,
      subject: "#{@group.name} - Weekly Question Digest"
    )
  end
end