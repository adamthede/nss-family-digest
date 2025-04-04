class Answer < ApplicationRecord
  belongs_to :question_record
  belongs_to :user

  has_rich_text :answer

  validates_presence_of :user
  validates_presence_of :question_record

  validate :answer_present?
  validate :answer_within_valid_period

  # --- Public Class Methods ---

  # Main entry point for creating an answer from an email
  def self.create_from_email(from, subject, textbody, headers = {})
    # Note: Calls private class methods defined below
    user = find_user_by_email(from)
    return unless user

    begin
      question_record = find_question_record_from_headers(headers) || find_question_record_from_subject(subject)

      unless question_record
        logger.error("Could not determine question record from email: from=#{from} subject=#{subject}")
        return
      end

      create_answer_if_cycle_active(user, question_record, textbody)

    rescue => e
      logger.error("Error processing email: #{e.message}")
      logger.error(e.backtrace.join("\n"))
      nil # Ensure nil is returned on error
    end
  end

  # --- Private Class Methods --- #
  class << self
    private

    # --- User Lookup ---
    def find_user_by_email(from)
      user = User.find_by_email(from.to_s)
      logger.info("No user found with email: #{from.to_s}") unless user
      user
    end

    # --- QuestionRecord Lookup Logic ---
    def find_question_record_from_headers(headers)
      return nil unless headers.present?

      group_id = headers['X-Answers2Answers-GroupId']
      question_id = headers['X-Answers2Answers-QuestionId']
      question_record_id = headers['X-Answers2Answers-QuestionRecordId']

      # Priority 1: Direct QuestionRecord ID
      if question_record_id.present?
        record = QuestionRecord.find_by(id: question_record_id)
        # Check if found record is still accepting answers
        if record && !QuestionRecord.accepting_answers.exists?(id: question_record_id)
          logger.info("Question record #{question_record_id} from headers exists but is no longer accepting answers.")
          # Try to find an alternative active record for the same group/question if possible
          return find_active_or_recent_record(group_id, question_id) if group_id.present? && question_id.present?
          return nil # No alternative possible or found
        end
        return record # Return found (and active) record or nil if not found initially
      end

      # Priority 2: Group ID and Question ID
      if group_id.present? && question_id.present?
        return find_active_or_recent_record(group_id, question_id)
      end

      nil # Headers present but didn't contain usable IDs
    end

    def find_question_record_from_subject(subject)
      logger.info("Headers not found or invalid, falling back to subject parsing")
      parsed_info = parse_subject_info(subject)
      return nil unless parsed_info

      question = find_question_from_normalized_text(parsed_info[:question_text])
      return nil unless question

      group = find_group_by_name(parsed_info[:group_name], subject) # Pass subject for logging
      return nil unless group

      find_active_or_recent_record(group.id.to_s, question.id.to_s)
    end

    # Finds an active record, falling back to the most recent if no active one exists
    def find_active_or_recent_record(group_id, question_id)
      QuestionRecord.find_active_record(group_id, question_id) ||
        QuestionRecord.most_recent_for(group_id, question_id).first
    end

    # --- Subject Parsing Helpers ---
    def parse_subject_info(subject)
      return nil unless subject.include?('*')

      question_parts = subject.split('*')
      question_text = question_parts[1]&.strip

      return nil unless question_text # No text between asterisks

      # Extract group name
      clean_subject = subject.sub(/^Re:\s*/, '') # Remove 'Re: ' prefix
      group_name = clean_subject.split('-').first&.strip

      unless group_name
        logger.error("Could not parse group name from subject: #{subject}")
        return nil
      end

      { question_text: question_text, group_name: group_name }
    end

    def find_question_from_normalized_text(text)
      normalized_text = text.gsub(/\s+/, ' ').strip
      # Use database function to normalize the 'question' column for comparison
      # Assumes PostgreSQL - adjust regexp_replace if using MySQL/SQLite
      question = Question.where("trim(regexp_replace(question, '\\s+', ' ', 'g')) = ?", normalized_text).first

      logger.error("Could not find question from subject fragment: #{text}") unless question
      question
    end

    def find_group_by_name(name, original_subject)
      group = Group.find_by_name(name)
      logger.error("No group found with name: '#{name}' from subject: #{original_subject}") unless group
      group
    end

    # --- Answer Creation Logic ---
    def create_answer_if_cycle_active(user, question_record, textbody)
      cycle = QuestionCycle.find_by(question_record_id: question_record.id)

      if cycle&.status_active?
        # Use create! to raise potential validation errors
        answer = Answer.create!(
          answer: textbody,
          user_id: user.id,
          question_record_id: question_record.id
        )
        logger.info("Successfully created answer ##{answer.id} for question record ##{question_record.id}")
        answer
      else
        logger.info("INVALID CYCLE STATUS: Answering has closed for this question (cycle status: #{cycle&.status}). Record ID: #{question_record.id}")
        nil
      end
    end
  end # end class << self

  # --- Instance Validations --- #
  # Note: These remain instance methods and are correctly affected by `private` if needed (though they seem intended to be public validations)
  private # This will correctly make instance methods below private if needed

  def answer_present?
    # Assuming ActionText, `answer.body.present?` might be needed if `answer` itself is the rich text object
    # Checking `read_attribute` handles cases before ActionText association is loaded/saved
    return if answer.present? && (!answer.respond_to?(:body) || answer.body.present?) || read_attribute(:answer).present?
    errors.add(:answer, "can't be blank")
  end

  def answer_within_valid_period
    # Fetch the cycle directly associated with the answer's question_record
    cycle = question_record&.question_cycle # Assumes `has_one :question_cycle` on QuestionRecord

    # If there's no cycle or it's not active, add an error
    if cycle.nil? || !cycle.status_active?
      # Fetch status for logging, handling nil cycle
      status = cycle ? cycle.status : 'no cycle found'
      logger.warn "Attempt to answer question record #{question_record_id} outside active cycle (Status: #{status})."
      errors.add(:base, "The question is no longer accepting answers.")
    end
  end
end
