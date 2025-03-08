class Answer < ApplicationRecord
  belongs_to :question_record
  belongs_to :user

  has_rich_text :answer

  validates_presence_of :user
  validates_presence_of :question_record

  validate :answer_present?

  def self.create_from_inbound_hook(message)
    puts message
    # self.new(:text => message["TextBody"],
    #          :user_email => message["From"],
    #          :discussion_id => message["MailboxHash"])
  end

  def self.create_from_email(from, subject, textbody)
    Rails.logger.info("Processing email from: #{from}, subject: #{subject}")

    if (user = User.find_by_email(from.to_s))
      Rails.logger.info("Found user: #{user.email}")

      # Extract question from between asterisks
      # Example: "Re: Questions with Laura - QUESTION: * What are your all-time favorite TV shows and TV stars? *"
      question_match = subject.match(/\*\s*(.*?)\s*\*/)

      if question_match && question_match[1].present?
        question_text = question_match[1].strip
        Rails.logger.info("Extracted question: #{question_text}")

        question = Question.find_by_question(question_text)

        if question
          Rails.logger.info("Found question with ID: #{question.id}")

          # Extract group name from the subject
          # Format is typically "Questions with [GROUP_NAME] - QUESTION: *..."
          group_match = subject.match(/Questions with\s+(.*?)\s+-/)

          if group_match && group_match[1].present?
            group_name = group_match[1].strip
            Rails.logger.info("Extracted group name: #{group_name}")

            group = Group.find_by_name(group_name)

            if group
              Rails.logger.info("Found group with ID: #{group.id}")

              question_record = QuestionRecord.where(group_id: group.id, question_id: question.id).last

              if question_record
                Rails.logger.info("Found question record with ID: #{question_record.id}")

                if DateTime.now < question_record.created_at + 5.days
                  answer = Answer.create(
                    answer: textbody,
                    user_id: user.id,
                    question_record_id: question_record.id
                  )

                  if answer.persisted?
                    Rails.logger.info("Successfully created answer with ID: #{answer.id}")
                    return answer
                  else
                    Rails.logger.error("Failed to create answer: #{answer.errors.full_messages.join(', ')}")
                  end
                else
                  Rails.logger.info("TOO LATE! Answering has closed for this question.")
                end
              else
                Rails.logger.error("No question record found for group ID: #{group.id} and question ID: #{question.id}")
              end
            else
              Rails.logger.error("No group found with name: #{group_name}")
            end
          else
            Rails.logger.error("Could not extract group name from subject: #{subject}")
          end
        else
          Rails.logger.error("No question found with text: #{question_text}")
        end
      else
        Rails.logger.error("Could not extract question from subject: #{subject}")
      end
    else
      Rails.logger.error("No user found with email: #{from}")
    end

    nil # Return nil if we couldn't create an answer
  end

  def self.send_answer_digest
    start_date = 7.days.ago
    end_date = DateTime.now
    question_record = QuestionRecord.where(:created_at => start_date..end_date)
    question_record.each do |record|
      group_id = record.group_id
      question_id = record.question_id
      group = Group.find(group_id)
      question = Question.find(question_id)
      answers = Answer.where(question_record_id: record.id)
      group.users.each do |user|
        QuestionMailer.weekly_digest(user, group, question, answers, record).deliver
      end
    end
  end

  private

  def answer_present?
    return if answer.present? || read_attribute(:answer).present?
    errors.add(:answer, "can't be blank")
  end

end
