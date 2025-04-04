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

    ##
    # Finds and returns the user associated with the given email address.
    #
    # Converts the provided value to a string and queries the User model. Logs an info
    # message if no matching user is found.
    #
    # @param from [#to_s] The email address to search for.
    # @return [User, nil] The user corresponding to the email, or nil if not found.
    def find_user_by_email(from)
      user = User.find_by_email(from.to_s)
      logger.info("No user found with email: #{from.to_s}") unless user
      user
    end

    ##
    # Finds a valid QuestionRecord based on provided headers.
    #
    # This method first attempts to locate a QuestionRecord using the 'X-Answers2Answers-QuestionRecordId' header.
    # If the record is found but is no longer accepting answers, and both 'X-Answers2Answers-GroupId' and
    # 'X-Answers2Answers-QuestionId' are present, it searches for an active or recent record alternative.
    # If a direct record ID is not provided, it attempts to find an active or recent record using group and question headers.
    #
    # @param headers [Hash] A hash containing headers such as 'X-Answers2Answers-QuestionRecordId',
    #   'X-Answers2Answers-GroupId', and 'X-Answers2Answers-QuestionId' used for locating a QuestionRecord.
    # @return [QuestionRecord, nil] The matching active QuestionRecord if found; otherwise, nil.
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

    ##
    # Extracts question and group details from an email subject to locate an active or recent question record.
    #
    # This method attempts to parse the subject using `parse_subject_info` to retrieve the question text and group name.
    # It then finds the corresponding question and group using normalized text search and group lookup, respectively.
    # Finally, it returns the active or most recent question record associated with the group and question.
    #
    # @param subject [String] The email subject line containing encoded question and group information.
    # @return [QuestionRecord, nil] The active or most recent question record if found, or nil if parsing fails or required records are missing.
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

    ##
    # Retrieves an active question record for a specified group and question.
    #
    # This method first attempts to locate an active record. If none is found,
    # it returns the most recent record for the given criteria.
    #
    # @param group_id [Integer] Identifier for the group associated with the question.
    # @param question_id [Integer] Identifier for the question.
    # @return [QuestionRecord, nil] The active or most recent question record, or nil if no record exists.
    def find_active_or_recent_record(group_id, question_id)
      QuestionRecord.find_active_record(group_id, question_id) ||
        QuestionRecord.most_recent_for(group_id, question_id).first
    end

    ##
    # Extracts the question text and group name from an email subject.
    #
    # The subject is expected to include a pair of asterisks (*) that delimit the question text.
    # An optional "Re:" prefix is removed, and the group name is extracted from the text
    # preceding a hyphen (-). If the subject does not conform to these requirements (e.g.,
    # missing asterisks, empty question text, or an unidentifiable group name), the method
    # returns nil.
    #
    # @param subject [String] The email subject to parse, expected to include '*' markers for
    #   question text and a '-' separator for the group name.
    # @return [Hash{Symbol => String}, nil] A hash with keys :question_text and :group_name if parsing succeeds,
    #   or nil otherwise.
    #
    # @example
    #   parse_subject_info("Re: Marketing - *What is our target market?*")
    #   # => { question_text: "What is our target market?", group_name: "Marketing" }
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

    ##
    # Retrieves a Question record by normalizing and matching the provided text fragment.
    #
    # This method removes extra whitespace from the input string by consolidating spaces and trimming leading/trailing spaces.
    # It then queries the Question model using PostgreSQL's regexp_replace function to normalize stored text for comparison.
    # An error is logged if no matching Question record is found.
    #
    # @param text [String] The text fragment to normalize and compare.
    # @return [Question, nil] The matching Question record if found; otherwise, nil.
    #
    # @note Adjust the SQL regular expression if using a database other than PostgreSQL.
    def find_question_from_normalized_text(text)
      normalized_text = text.gsub(/\s+/, ' ').strip
      # Use database function to normalize the 'question' column for comparison
      # Assumes PostgreSQL - adjust regexp_replace if using MySQL/SQLite
      question = Question.where("trim(regexp_replace(question, '\\s+', ' ', 'g')) = ?", normalized_text).first

      logger.error("Could not find question from subject fragment: #{text}") unless question
      question
    end

    ##
    # Finds a group by its name.
    #
    # Searches for a group with the specified name. If no matching group is found,
    # logs an error that includes the original subject from which the group name was extracted.
    #
    # @param name [String] the name of the group to locate.
    # @param original_subject [String] the original subject line used to derive the group name, provided for context in logging.
    # @return [Group, nil] the group object if found; otherwise, nil.
    def find_group_by_name(name, original_subject)
      group = Group.find_by_name(name)
      logger.error("No group found with name: '#{name}' from subject: #{original_subject}") unless group
      group
    end

    ##
    # Creates an answer for the given question record if its associated question cycle is active.
    #
    # This method checks whether the question cycle related to the specified question record is active.
    # If active, it creates an Answer using the provided text body; otherwise, it returns nil.
    #
    # @param user [User] the user submitting the answer.
    # @param question_record [QuestionRecord] the question record being answered.
    # @param textbody [String] the content of the answer.
    # @return [Answer, nil] the newly created Answer when the cycle is active; nil if the cycle is inactive.
    # @raise [ActiveRecord::RecordInvalid] if answer creation fails due to validation errors.
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
  private ##
  # Validates that the answer content is present.
  #
  # This method checks whether the answer is provided either via its rich text association (ensuring that the associated
  # rich text's body is not empty) or through the raw attribute using `read_attribute`. If no content is found, a "can't be blank"
  # error is added to the record.
  #
  # @return [void]

  def answer_present?
    # Assuming ActionText, `answer.body.present?` might be needed if `answer` itself is the rich text object
    # Checking `read_attribute` handles cases before ActionText association is loaded/saved
    return if answer.present? && (!answer.respond_to?(:body) || answer.body.present?) || read_attribute(:answer).present?
    errors.add(:answer, "can't be blank")
  end

  ##
  # Validates that the answer is submitted during an active question cycle.
  #
  # Retrieves the cycle associated with the answer's question record and checks if it is active.
  # If no cycle exists or the cycle is inactive, logs a warning with the current cycle status
  # and adds a validation error to prevent submission outside of the allowed period.
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
