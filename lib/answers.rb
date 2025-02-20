module Answers
  def self.send!
    QuestionRecord.where('created_at > ?', 1.week.ago).find_each do |record|
      # Get active users for the group at the time of sending
      active_users = record.group.active_users

      next if active_users.empty?

      # Get answers from the past week
      answers = record.answers.where('created_at > ?', 1.week.ago)

      # Only send digest if there are answers
      next if answers.empty?

      # Send digest only to active users
      active_users.each do |user|
        AnswerMailer.digest_email(user, record, answers).deliver
      end
    end
  end
end
