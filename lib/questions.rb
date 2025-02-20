module Questions
  def self.run!
    Group.find_each do |group|
      # Only get active users for the group
      active_users = group.active_users

      next if active_users.empty?

      # Get a random question that hasn't been used for this group
      available_questions = group.available_questions
        .where.not(id: group.recorded_questions.pluck(:id))

      if question = available_questions.sample
        # Create question record
        question_record = group.question_records.create!(question: question)

        # Send email only to active users
        active_users.each do |user|
          QuestionMailer.question_email(user, question_record).deliver
        end
      end
    end
  end
end
