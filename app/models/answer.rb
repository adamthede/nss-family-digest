class Answer < ApplicationRecord
  belongs_to :question_record
  belongs_to :user

  has_rich_text :answer

  validates_presence_of :user
  validates_presence_of :question_record

  validate :answer_present?
  validate :answer_within_valid_period

  def self.create_from_email(from, subject, textbody, headers = {})
    if (user = User.find_by_email(from.to_s))
      begin
        question_record = nil

        # Primary method: Use headers if available
        if headers.present?
          group_id = headers['X-Answers2Answers-GroupId']
          question_id = headers['X-Answers2Answers-QuestionId']
          question_record_id = headers['X-Answers2Answers-QuestionRecordId']

          # If question_record_id is directly available, use it
          if question_record_id.present?
            question_record = QuestionRecord.find_by(id: question_record_id)

            # Check if the record exists but is no longer accepting answers
            unless QuestionRecord.accepting_answers.exists?(id: question_record_id)
              logger.info("Question record #{question_record_id} exists but is no longer accepting answers.")
              # Try to find another active question record for the same group/question
              if group_id.present? && question_id.present?
                question_record = QuestionRecord.find_active_record(group_id, question_id)
              end
            end
          elsif group_id.present? && question_id.present?
            # Look for an active question record
            question_record = QuestionRecord.find_active_record(group_id, question_id)

            # If no active record, try getting the most recent one
            if question_record.nil?
              question_record = QuestionRecord.most_recent_for(group_id, question_id).first
            end
          end
        end

        # Fallback: Parse from subject if headers are not available
        if question_record.nil?
          logger.info("Headers not found or invalid, falling back to subject parsing")

          # Extract question text between asterisks
          if subject.include?('*')
            question_parts = subject.split('*')
            question_text = question_parts[1].strip if question_parts.length > 1

            # Look up the question by text, normalizing whitespace
            if question_text
              normalized_text = question_text.gsub(/\s+/, ' ').strip
              # Use database function to normalize the 'question' column for comparison
              # Assumes PostgreSQL - adjust regexp_replace if using MySQL/SQLite
              question_obj = Question.where("trim(regexp_replace(question, '\\s+', ' ', 'g')) = ?", normalized_text).first
            else
              question_obj = nil
            end

            if question_obj.nil?
              logger.error("Could not find question from subject: #{subject}")
              return
            end

            question_id = question_obj.id.to_s

            # Extract group name from the subject before the dash
            clean_subject = subject
            if clean_subject.start_with?('Re: ')
              clean_subject = clean_subject[4..-1] # Remove 'Re: ' prefix
            end

            # Try to get group name (everything before the dash)
            group_name = nil
            if clean_subject.include?('-')
              group_name = clean_subject.split('-').first.strip
            else
              # If no dash, try another approach or log error
              logger.error("Could not parse group name from subject: #{subject}")
              return
            end

            group = Group.find_by_name(group_name)

            if group.nil?
              logger.error("No group found with name: '#{group_name}' from subject: #{subject}")
              return
            end

            group_id = group.id.to_s

            # Find an active question record first
            question_record = QuestionRecord.find_active_record(group_id, question_id)

            # If no active record, fall back to most recent
            if question_record.nil?
              question_record = QuestionRecord.most_recent_for(group_id, question_id).first
            end
          end
        end

        if question_record.nil?
          logger.error("Could not determine question record from email: from=#{from} subject=#{subject}")
          return
        end

        # Check if question is in an active cycle
        cycle = QuestionCycle.find_by(question_record_id: question_record.id)
        if cycle && cycle.status_active?
          answer = Answer.create(
            answer: textbody,
            user_id: user.id,
            question_record_id: question_record.id
          )
          logger.info("Successfully created answer ##{answer.id} for question record ##{question_record.id}")
          return answer
        else
          logger.info("INVALID CYCLE STATUS: Answering has closed for this question (cycle status: #{cycle&.status}).")
        end
      rescue => e
        logger.error("Error processing email: #{e.message}")
        logger.error(e.backtrace.join("\n"))
      end
    else
      logger.info("No user found with email: #{from.to_s}")
    end
    nil
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
