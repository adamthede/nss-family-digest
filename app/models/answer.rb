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
    # Retrieves a user corresponding to the specified email address.
    #
    # The method converts the input to a string and searches for a matching user record.
    # If no matching user is found, an informational log is generated.
    #
    # @param from [#to_s] An email address or an object convertible to a string.
    # @return [User, nil] The found user, or nil if no user matches the email.
    def find_user_by_email(from)
      user = User.find_by_email(from.to_s)
      logger.info("No user found with email: #{from.to_s}") unless user
      user
    end

    ##
    # Retrieves a QuestionRecord using provided header information.
    #
    # This method first attempts to locate a question record by a direct identifier from the headers.
    # If a "QuestionRecordId" is present but the record is not accepting answers, it will try to find
    # an alternative active record using the "GroupId" and "QuestionId" headers. Returns nil if the
    # headers are missing or do not yield a valid, active record.
    #
    # @param headers [Hash] Header values that may include 'X-Answers2Answers-QuestionRecordId',
    #                        'X-Answers2Answers-GroupId', and 'X-Answers2Answers-QuestionId'.
    # @return [QuestionRecord, nil] The valid, active question record if found, or nil otherwise.
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
    # Extracts question and group information from the email subject and returns the corresponding question record.
    #
    # This method parses the subject to obtain the question text and group name, looks up the associated question and group, and then retrieves
    # an active or the most recent question record based on these details. It returns nil if any of the required information cannot be found.
    #
    # @param subject [String] The email subject containing encoded question text and group name.
    # @return [QuestionRecord, nil] The active or most recent question record if found; otherwise, nil.
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
    # Retrieves an active question record for the specified group and question.
    #
    # If no active record exists, falls back to returning the most recent available record.
    #
    # @param group_id [Integer] Identifier for the group associated with the question record.
    # @param question_id [Integer] Identifier for the question.
    # @return [QuestionRecord, nil] The active question record or the most recent one if active record is absent, or nil if no record is found.
    def find_active_or_recent_record(group_id, question_id)
      QuestionRecord.find_active_record(group_id, question_id) ||
        QuestionRecord.most_recent_for(group_id, question_id).first
    end

    ##
    # Parses an email subject to extract the question text and group name.
    #
    # The subject must contain a section enclosed by asterisks ('*') representing the question text.
    # Any leading "Re:" prefix is removed, and the group name is extracted as the first component 
    # from the subject before a hyphen ('-'). If the subject lacks the required format or parsing fails,
    # the method returns nil.
    #
    # @param subject [String] The email subject containing the question and group information.
    # @return [Hash{Symbol=>String}, nil] A hash with keys :question_text and :group_name if parsing is successful; nil otherwise.
    #
    # @example
    #   parse_subject_info("Re: Sales Team - *What time is the meeting?*")
    #   # => { question_text: "What time is the meeting?", group_name: "Sales Team" }
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
    # Finds a Question record by matching its normalized text against the provided input.
    #
    # The provided text is normalized by collapsing multiple whitespace characters into a single space and trimming leading or trailing whitespace.
    # The database query applies a similar normalization to the question field using PostgreSQL's regexp_replace function.
    # An error is logged if no matching Question record is found.
    #
    # @param text [String] the text fragment to be normalized and used for matching
    # @return [Question, nil] the matching Question record if found; otherwise, nil
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
    # Searches for a group record using the provided name. If no group is found, logs
    # an error that includes the original subject for additional context.
    #
    # @param name [String] The name of the group to locate.
    # @param original_subject [String] The original subject used for error logging if the group is not found.
    # @return [Group, nil] The group record if found; otherwise, nil.
    def find_group_by_name(name, original_subject)
      group = Group.find_by_name(name)
      logger.error("No group found with name: '#{name}' from subject: #{original_subject}") unless group
      group
    end

    ##
    # Creates an answer record if the associated question cycle is active.
    #
    # This method retrieves the question cycle for the provided question record and checks if the cycle is active.
    # If active, it creates an answer linked to the given user and question record using `create!` and returns the created answer.
    # If the cycle is not active, the method returns nil.
    #
    # @param user [User] The user submitting the answer.
    # @param question_record [QuestionRecord] The question record being answered.
    # @param textbody [String] The content of the answer.
    # @return [Answer, nil] The created answer if the cycle is active, or nil otherwise.
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
  # Validates that an answer is present.
  #
  # This validation method checks whether the answer is provided either as a rich text attribute (with a non-empty
  # body, if applicable) or via the raw attribute stored in the database. If neither check passes, an error is added
  # indicating that the answer can't be blank.

  def answer_present?
    # Assuming ActionText, `answer.body.present?` might be needed if `answer` itself is the rich text object
    # Checking `read_attribute` handles cases before ActionText association is loaded/saved
    return if answer.present? && (!answer.respond_to?(:body) || answer.body.present?) || read_attribute(:answer).present?
    errors.add(:answer, "can't be blank")
  end

  ##
  # Validates that the answer is submitted during an active cycle.
  #
  # Checks if the associated question_record has a question_cycle that is active. If no cycle is found or the
  # cycle is inactive, the method logs a warning and adds a base error indicating that the question is no longer
  # accepting answers.
  #
  # @note Assumes that question_record has a has_one association with question_cycle.
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
