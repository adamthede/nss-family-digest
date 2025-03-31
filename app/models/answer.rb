class Answer < ApplicationRecord
  belongs_to :question_record
  belongs_to :user

  has_rich_text :answer

  validates_presence_of :user
  validates_presence_of :question_record

  validate :answer_present?
  validate :answer_within_valid_period

  def self.create_from_email(from, subject, textbody)
    if (user = User.find_by_email(from.to_s))
      begin
        # Extract question text between asterisks
        if subject.include?('*')
          # Get text between the asterisks
          question_parts = subject.split('*')
          question = question_parts[1].strip if question_parts.length > 1
        end

        # Look up the question
        question_obj = question ? Question.find_by_question(question) : nil

        if question_obj.nil?
          logger.error("Could not find question from subject: #{subject}")
          return
        end

        question_id = question_obj.id.to_s

        # Extract group name from the "Questions with X" format
        if subject.include?('Questions with ')
          group_text = subject.scan(/Questions with ([^-]+)/).flatten.first&.strip
          group = group_text ? Group.find_by_name(group_text) : nil
        else
          # Try extracting from the first part of the subject
          groupname = subject.split('-').first.strip
          if groupname.start_with?('Re: ')
            groupname = groupname[4..-1] # Remove 'Re: ' prefix
          end
          group = Group.find_by_name(groupname)
        end

        if group.nil?
          logger.error("Could not find group from subject: #{subject}")
          return
        end

        group_id = group.id.to_s

        # Find the question record
        question_record = QuestionRecord.where(group_id: group_id, question_id: question_id).last

        if question_record.nil?
          logger.error("Could not find question record for group_id: #{group_id}, question_id: #{question_id}")
          return
        end

        question_record_id = question_record.id.to_s

        # Check if question is in an active cycle
        cycle = QuestionCycle.find_by(question_record_id: question_record_id)
        if cycle && cycle.status == 'active'
          Answer.create(answer: textbody,
                      user_id: user.id,
                      question_record_id: question_record_id)
        else
          logger.info("INVALID CYCLE STATUS: Answering has closed for this question.")
        end
      rescue => e
        logger.error("Error processing email: #{e.message}")
        logger.error(e.backtrace.join("\n"))
      end
    else
      logger.info("No user found with email: #{from.to_s}")
    end
  end

  private

  def answer_present?
    return if answer.present? || read_attribute(:answer).present?
    errors.add(:answer, "can't be blank")
  end

  def answer_within_valid_period
    # Get the question cycle
    cycle = QuestionCycle.find_by(question_record_id: question_record_id)

    if cycle && cycle.status != 'active'
      errors.add(:base, "The question is no longer accepting answers")
    end
  end
end
