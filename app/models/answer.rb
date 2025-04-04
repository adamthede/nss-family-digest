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
    # Finds a user record by their email address.
    #
    # Converts the input to its string representation and searches for a matching User record.
    # If no user is found, an informational message is logged.
    #
    # @param from [#to_s] The email address used in the lookup.
    # @return [User, nil] The user corresponding to the given email address, or nil if not found.
    def find_user_by_email(from)
      user = User.find_by_email(from.to_s)
      logger.info("No user found with email: #{from.to_s}") unless user
      user
    end

    ##
    # Finds and returns an active QuestionRecord based on header information.
    #
    # This method extracts potential identifiers from the given headers, including a direct
    # QuestionRecord ID, group ID, and question ID. If a direct ID is provided, it verifies that
    # the corresponding record is actively accepting answers; if not, or if only group and question
    # identifiers are available, it attempts to retrieve an active or recent record using those values.
    #
    # @param headers [Hash] a set of header values that may include:
    #   - "X-Answers2Answers-QuestionRecordId": direct identifier of the QuestionRecord.
    #   - "X-Answers2Answers-GroupId": group identifier.
    #   - "X-Answers2Answers-QuestionId": question identifier.
    # @return [QuestionRecord, nil] an active QuestionRecord suitable for answering, or nil if none is found.
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
    # Extracts question and group information from an email subject and returns the corresponding question record.
    #
    # This method parses the provided email subject to retrieve the normalized question text and group name.
    # It then looks up the matching question and group records, and if both are found, returns an active
    # or the most recent question record associated with them. Returns nil if parsing fails or if any record
    # cannot be found.
    #
    # @param subject [String] the email subject containing encoded question and group information.
    # @return [QuestionRecord, nil] the active or most recent question record if found; otherwise, nil.
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
    # Retrieves an active QuestionRecord for the given group and question.
    #
    # If no active record is found, it returns the most recent record available.
    #
    # @param group_id [Integer] the ID of the group associated with the question
    # @param question_id [Integer] the ID of the question to look up
    # @return [QuestionRecord, nil] the active or most recent QuestionRecord, or nil if none exists
    def find_active_or_recent_record(group_id, question_id)
      QuestionRecord.find_active_record(group_id, question_id) ||
        QuestionRecord.most_recent_for(group_id, question_id).first
    end

    ##
    # Parses an email subject to extract the question text and group name.
    #
    # The subject must contain the question text wrapped between a pair of asterisks (*).
    # Optionally, a "Re:" prefix is removed before extracting the group name, which is taken
    # as the substring preceding the first hyphen (-). Returns a hash with the extracted
    # information if the subject meets the expected format, or nil otherwise.
    #
    # @param subject [String] The email subject line to parse.
    # @return [Hash, nil] A hash with keys :question_text and :group_name if parsing is successful; nil otherwise.
    #
    # @example
    #   parse_subject_info("Re: Sales - *What are our targets?*")
    #   # => { question_text: "What are our targets?", group_name: "Sales" }
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
    # Finds a question record that matches the normalized version of the provided text.
    #
    # The method normalizes the input text by collapsing multiple whitespace characters
    # into a single space and trimming any leading or trailing spaces. It then compares this
    # normalized text with a similarly normalized version of the 'question' column in the
    # database using a PostgreSQL-specific SQL query.
    #
    # @param text [String] The text fragment to normalize and search for.
    # @return [Question, nil] The first question record that matches the normalized text, or nil if no match is found.
    # @note Logs an error if no matching question record is found.
    def find_question_from_normalized_text(text)
      normalized_text = text.gsub(/\s+/, ' ').strip
      # Use database function to normalize the 'question' column for comparison
      # Assumes PostgreSQL - adjust regexp_replace if using MySQL/SQLite
      question = Question.where("trim(regexp_replace(question, '\\s+', ' ', 'g')) = ?", normalized_text).first

      logger.error("Could not find question from subject fragment: #{text}") unless question
      question
    end

    ##
    # Finds a group record by name.
    #
    # This method retrieves a group using the given name. If no matching group is found, it logs an error
    # message including the original subject from which the group name was derived.
    #
    # @param name [String] the name of the group to locate.
    # @param original_subject [String] the subject text used for contextual logging when the group is not found.
    # @return [Group, nil] the found group, or nil if no group exists with the specified name.
    def find_group_by_name(name, original_subject)
      group = Group.find_by_name(name)
      logger.error("No group found with name: '#{name}' from subject: #{original_subject}") unless group
      group
    end

    ##
    # Creates an answer for the given question record if its question cycle is active.
    #
    # This method first retrieves the question cycle associated with the specified question record.
    # If the cycle is active, it creates an answer using the provided text body, logs the successful
    # creation, and returns the answer. If the cycle is inactive or missing, it logs that the answering
    # period has closed and returns nil.
    #
    # @param user [User] The user submitting the answer.
    # @param question_record [QuestionRecord] The question record to which the answer is associated.
    # @param textbody [String] The content of the answer.
    #
    # @return [Answer, nil] The newly created answer if the question cycle is active; otherwise, nil.
    #
    # @raise [ActiveRecord::RecordInvalid] If the answer fails validations during creation.
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
  # Validates that the answer is present.
  #
  # This method checks whether the answer contains content by verifying both its rich text
  # association (if applicable) and its raw attribute. If neither contains data, it adds an error
  # indicating that the answer cannot be blank.
  #
  # @return [void]

  def answer_present?
    # Assuming ActionText, `answer.body.present?` might be needed if `answer` itself is the rich text object
    # Checking `read_attribute` handles cases before ActionText association is loaded/saved
    return if answer.present? && (!answer.respond_to?(:body) || answer.body.present?) || read_attribute(:answer).present?
    errors.add(:answer, "can't be blank")
  end

  ##
  # Validates that the answer is submitted within the active period of its associated question cycle.
  #
  # Retrieves the question cycle from the answer's question_record and verifies its active status. If no cycle is found or the cycle is inactive, a warning is logged and an error is added to the record indicating that the question is no longer accepting answers.
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
