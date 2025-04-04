class EmailReplyService
  attr_reader :inbound_email, :params, :from_email, :subject, :content, :identification_method

  # Class method for processing an email reply
  def self.process_reply(inbound_email)
    new(inbound_email).process
  end

  ##
  # Initializes a new instance of EmailReplyService.
  #
  # Processes the inbound email payload by converting its keys to symbols for easier access,
  # and extracts important details such as the sender's email, subject, and content.
  # The raw content is determined from the available text or HTML fields, and a cleaned version
  # of the content is prepared for further processing.
  #
  # @param inbound_email [InboundEmail] The email object containing the payload with email details.
  def initialize(inbound_email)
    @inbound_email = inbound_email
    # Use symbolized keys for easier access to the payload hash
    @params = inbound_email.payload.deep_symbolize_keys
    @from_email = extract_email
    @subject = @params[:subject] || ''
    @raw_content = @params[:text] || @params[:html] || ""
    @content = extract_content
    @identification_method = nil
  end

  ##
  # Processes an inbound email reply.
  #
  # This method updates the inbound email status to "processing" and then performs sequential validations:
  #   - It verifies that the sender's email corresponds to a valid user.
  #   - It locates and validates the associated question record.
  #   - It checks whether the sender is an eligible recipient for the question.
  #   - It confirms that the question cycle is active.
  #
  # If all checks pass, the method attempts to create and save an answer; otherwise, it invokes the corresponding error handler.
  # Any unexpected error is caught and handled by updating the email status appropriately.
  def process
    update_inbound_email(status: 'processing', notes: "Starting processing...")

    user = find_and_validate_user
    return handle_user_not_found unless user

    question_record = find_and_validate_question_record
    return handle_question_record_not_found unless question_record

    return handle_recipient_validation_failed(user, question_record) unless verify_recipient(user, question_record)

    active_cycle = verify_active_cycle(question_record)
    return handle_inactive_cycle(question_record, active_cycle) unless active_cycle

    # If all checks pass, attempt to create the answer
    create_and_save_answer(user, question_record)

  rescue => e
    handle_unexpected_error(e)
  end

  private

  ##
  # Retrieves a user record corresponding to the sender's email address.
  #
  # Uses the instance's `from_email` to search for a matching user in the system.
  # Returns the user object if found; otherwise, returns nil.
  #
  # @return [User, nil] The user object if a match is found, or nil if none exists.

  def find_and_validate_user
    User.find_by_email(from_email)
  end

  ##
  # Finds and validates the question record associated with the inbound email reply.
  #
  # Delegates to {#identify_question_record} to locate and verify the relevant question record.
  #
  # @return [QuestionRecord, nil] the identified question record if found; otherwise, nil.
  def find_and_validate_question_record
    identify_question_record
  end

  ##
  # Verifies that the given user is an authorized recipient for the provided question record.
  #
  # This method delegates to the internal recipient validation logic to check if the user
  # is eligible to respond to the question represented by the question record.
  #
  # @param user [User] the user attempting to reply
  # @param question_record [QuestionRecord] the question record to which the reply corresponds
  # @return [Boolean] true if the user is a valid recipient; false otherwise
  def verify_recipient(user, question_record)
    validate_recipient(user, question_record)
  end

  ##
  # Returns the active cycle associated with the provided question record.
  #
  # This method retrieves the `QuestionCycle` using the question record's ID and returns it only
  # if the cycle is active; otherwise, it returns nil.
  #
  # @param question_record [Object] A record that has an identifiable ID used to find the associated cycle.
  # @return [QuestionCycle, nil] The active cycle if it exists and is active; nil otherwise.
  def verify_active_cycle(question_record)
    cycle = QuestionCycle.find_by(question_record_id: question_record.id)
    cycle if cycle&.active?
  end

  ##
  # Creates and saves an answer associated with the given user and question record.
  #
  # This method constructs a new Answer using the instance's content and links it to the specified user and question record. If the Answer is saved successfully, the inbound email record is updated to reflect the successful processing with notes that include the identification method used, and an "answer_created" event is logged. On failure to save, error handling is delegated to `handle_answer_creation_failure`.
  #
  # @param user [User] The user who authored the answer.
  # @param question_record [QuestionRecord] The related question record for which the answer is provided.
  # @return [Hash] A hash indicating success with the created answer, or the result from the answer creation failure handler.
  def create_and_save_answer(user, question_record)
    answer = Answer.new(
      answer: content,
      user_id: user.id,
      question_record_id: question_record.id
    )

    if answer.save
      notes = "Answer ##{answer.id} created successfully via #{identification_method}."
      update_inbound_email(status: 'processed', notes: notes, answer_id: answer.id)
      log_event("answer_created", {
        identification_method: identification_method,
        question_record_id: question_record.id,
        answer_id: answer.id,
        user_id: user.id
      })
      { success: true, answer: answer }
    else
      handle_answer_creation_failure(answer, user, question_record)
    end
  end

  ##
  # Handles the case when no user is found by updating the inbound email status, logging the error event,
  # and returning a failure response.
  #
  # Constructs an error message based on the sender's email, updates the inbound email record with a status
  # of 'failed', logs a "no_user_found" event with the sender's email, and returns a hash indicating failure.
  #
  # @return [Hash] A hash containing :success set to false and an :error message detailing the issue.

  def handle_user_not_found
    error_msg = "No user found with email: #{from_email}"
    update_inbound_email(status: 'failed', notes: error_msg)
    log_event("no_user_found", { email: from_email })
    { success: false, error: error_msg }
  end

  ##
  # Handles the case where the question record could not be identified.
  #
  # Constructs an error message based on the identification method used (or defaults to "unknown"),
  # updates the inbound email record with a failed status and error notes, logs a "question_record_not_found"
  # event with details including the sender's email and subject, and returns a hash indicating failure.
  #
  # @return [Hash] A hash with keys :success (false) and :error (the error message).
  def handle_question_record_not_found
    # identification_method is set within identify_question_record
    error_msg = "Could not identify the question record using method: #{identification_method || 'unknown'}"
    update_inbound_email(status: 'failed', notes: error_msg)
    log_event("question_record_not_found", {
      identification_method: identification_method || "failed",
      email: from_email,
      subject: subject
    })
    { success: false, error: error_msg }
  end

  ##
  # Handles a recipient validation failure by updating the inbound email status and logging the event.
  #
  # When the sender's email is not recognized as an active member of the group associated with the question record,
  # this method constructs an error message, updates the inbound email status to 'failed', logs a "recipient_validation_failed"
  # event with relevant identifiers, and returns a failure hash.
  #
  # @param user [User] The user object corresponding to the email sender.
  # @param question_record [QuestionRecord] The record representing the question related to the email.
  # @return [Hash] A hash with keys:
  #   - :success [Boolean] Set to false.
  #   - :error [String] The error message describing the recipient validation failure.
  def handle_recipient_validation_failed(user, question_record)
    error_msg = "Recipient validation failed: Email from #{from_email} is not an active member of group #{question_record.group_id}."
    update_inbound_email(status: 'failed', notes: error_msg)
    log_event("recipient_validation_failed", {
      user_id: user.id,
      question_record_id: question_record.id
    })
    { success: false, error: error_msg }
  end

  ##
  # Handles the scenario when a question's cycle is inactive.
  #
  # This method updates the inbound email status to "failed" with an error message indicating that the question is no longer accepting answers.
  # It also logs an "inactive_cycle" event with details from the question record and cycle.
  #
  # @param question_record [#id] The question record that is not accepting answers.
  # @param cycle [#id, #status, nil] The associated cycle, which may be nil; if present, it should provide its identifier and status.
  # @return [Hash] A hash with keys:
  #   - :success [Boolean] Always false.
  #   - :error [String] A descriptive error message.
  def handle_inactive_cycle(question_record, cycle) # Cycle might be nil
    error_msg = "The question (QR: #{question_record.id}) is no longer accepting answers (Cycle: #{cycle&.id}, Status: #{cycle&.status})."
    update_inbound_email(status: 'failed', notes: error_msg)
    log_event("inactive_cycle", {
      identification_method: identification_method,
      question_record_id: question_record.id,
      cycle_status: cycle&.status
    })
    { success: false, error: error_msg }
  end

  ##
  # Handles failure during answer creation by updating the inbound email status,
  # logging the error event, and returning an error response.
  #
  # Extracts validation error messages from the provided answer object, updates the inbound
  # email record to indicate a failure, and logs the failure event with details from the user
  # and the associated question record.
  #
  # @param answer [Answer] The answer object that failed to save, providing error messages.
  # @param user [User] The user who attempted to create the answer.
  # @param question_record [QuestionRecord] The question record the answer was associated with.
  # @return [Hash] A hash containing:
  #   - :success [Boolean] always false,
  #   - :error [String] the error message detailing why answer creation failed.
  def handle_answer_creation_failure(answer, user, question_record)
    error_msg = "Failed to create answer: #{answer.errors.full_messages.join(', ')}"
    update_inbound_email(status: 'failed', notes: error_msg)
    log_event("answer_creation_failed", {
      identification_method: identification_method,
      question_record_id: question_record.id,
      user_id: user.id,
      errors: answer.errors.full_messages
    })
    { success: false, error: error_msg }
  end

  ##
  # Handles an unexpected error during email reply processing.
  #
  # Logs the provided error message, updates the inbound email status to 'failed' with details
  # (if an inbound email record exists), and returns a failure response hash containing the error information.
  #
  # @param error [Exception] The encountered exception.
  # @return [Hash] A hash with :success set to false and :error containing a detailed error message.
  def handle_unexpected_error(error)
    error_msg = "Unexpected error: #{error.message} - Backtrace: #{error.backtrace.first(5).join("\\n")}"
    # Ensure update happens even if inbound_email is nil, though unlikely
    update_inbound_email(status: 'failed', notes: error_msg) if @inbound_email
    Rails.logger.error error_msg
    # Optionally, notify admins here
    { success: false, error: error_msg }
  end

  ##
  # Updates the inbound email record with the given processing details.
  #
  # Sets the email's new status, processor notes, and marks the processed timestamp as the current time.
  # Optionally, it associates an answer identifier if one is provided.
  #
  # @param status [String] The new status to assign to the inbound email.
  # @param notes [String] Relevant notes describing the processing outcome.
  # @param answer_id [Integer, nil] (optional) The identifier of the associated answer, if available.

  def update_inbound_email(status:, notes:, answer_id: nil)
    inbound_email.update(
      status: status,
      processor_notes: notes,
      processed_at: Time.current,
      answer_id: answer_id
    )
  end

  ##
  # Extracts the sender's email address from the inbound email payload.
  #
  # The method first checks for an envelope in the params hash and returns its :from value if present.
  # Otherwise, it falls back to the :from header and extracts an email address enclosed in angle brackets,
  # if available.
  #
  # @return [String, nil] The extracted sender email address, or nil if not found.
  def extract_email
    # Use symbolized keys for the params hash
    envelope = params[:envelope] || {}
    return envelope[:from] if envelope[:from].present?

    from_header = params[:from]
    if from_header =~ /<(.+?)>/
      Regexp.last_match(1)
    else
      from_header
    end
  end

  ##
  # Extracts and sanitizes the content from the raw email payload.
  #
  # This method checks the raw email content for a reply delimiter (specified by
  # ApplicationMailer::REPLY_DELIMITER). If the delimiter is present, the content
  # before its first occurrence is extracted; otherwise, the full raw content is used.
  # The extracted text is then cleaned using EmailReplyParser to remove any quoted text.
  #
  # @return [String] The cleaned email reply content.
  def extract_content
    # Find and split at the reply delimiter if present
    delimiter = ApplicationMailer::REPLY_DELIMITER
    content = if @raw_content.include?(delimiter)
                @raw_content.split(delimiter).first
              else
                @raw_content
              end

    # Use EmailReplyParser to clean up quoted text
    EmailReplyParser.parse_reply(content)
  end

  ##
  # Attempts to identify and return the question record associated with the inbound email
  # by sequentially applying multiple identification methods.
  #
  # It first tries to determine the record via the signed reply-to address. If unsuccessful,
  # it falls back to analyzing the email headers, then the email subject. If none of these
  # methods yield a valid record, the failure handler is invoked.
  #
  # @return [QuestionRecord, nil] the identified question record if found; otherwise, nil
  def identify_question_record
    # Try each identification method in order of preference
    identify_by_signed_reply_to ||
      identify_by_headers ||
      identify_by_subject ||
      handle_identification_failure
  end

  ##
  # Identifies a QuestionRecord using a signed reply-to address.
  #
  # This method attempts to extract a record ID from the reply-to header. If successful, it sets the identification
  # method to "signed_reply_to" and retrieves the corresponding QuestionRecord. The record is returned only if it exists
  # and is currently accepting answers; otherwise, the method tries to extract group and question IDs from the email envelope's
  # "to" field to locate an active or recent record.
  #
  # @return [QuestionRecord, nil] The identified active question record or nil if none is found.
  def identify_by_signed_reply_to
    record_id = extract_record_id_from_reply_to
    return nil unless record_id

    @identification_method = "signed_reply_to"
    record = QuestionRecord.find_by(id: record_id)

    return record if record && QuestionRecord.accepting_answers.exists?(id: record_id)

    # If record exists but not accepting answers, try to find another active one
    group_id = params[:envelope]&.dig(:to)&.match(/group-(\d+)/)&.[](1)
    question_id = params[:envelope]&.dig(:to)&.match(/question-(\d+)/)&.[](1)

    find_active_or_recent_record(group_id, question_id) if group_id && question_id
  end

  ##
  # Identifies a question record using email headers.
  #
  # This method first retrieves the email headers using `extract_headers`. If no headers are present,
  # it returns nil. It then sets the identification method to "headers" and attempts to locate a valid
  # question record following two strategies:
  #
  # 1. Direct Record ID: It checks for a "X-Answers2Answers-QuestionRecordId" header and returns the
  #    associated question record if it exists and is currently accepting answers.
  #
  # 2. Group and Question IDs: If no valid record is found via the direct ID, it extracts the
  #    "X-Answers2Answers-GroupId" and "X-Answers2Answers-QuestionId" headers. When both are present,
  #    it returns the active or most recent matching question record.
  #
  # @return [QuestionRecord, nil] The identified question record if one exists; otherwise, nil.
  def identify_by_headers
    headers = extract_headers
    return nil unless headers.present?

    @identification_method = "headers"

    # Try direct record ID first
    if (record_id = headers[:"X-Answers2Answers-QuestionRecordId"])
      record = QuestionRecord.find_by(id: record_id)
      return record if record && QuestionRecord.accepting_answers.exists?(id: record_id)
    end

    # Try group and question IDs
    group_id = headers[:"X-Answers2Answers-GroupId"]
    question_id = headers[:"X-Answers2Answers-QuestionId"]

    return nil unless group_id && question_id

    find_active_or_recent_record(group_id, question_id)
  end

  ##
  # Identifies an active or recent question record by parsing the email subject.
  #
  # This method checks if the email subject contains an asterisk ("*"), which signals that the subject
  # follows a specific format for reply identification. It then sets the identification method to "subject_parsing"
  # and attempts to extract a question and its associated group from the subject. If both are successfully retrieved,
  # it returns the active or recent record corresponding to the parsed group and question; otherwise, it returns nil.
  #
  # @return [Object, nil] the active or recent question record if found, or nil if the subject format is incorrect
  #   or the necessary identifiers cannot be extracted.
  def identify_by_subject
    return nil unless subject.include?('*')

    @identification_method = "subject_parsing"

    question = find_question_from_subject
    return nil unless question

    group = find_group_from_subject
    return nil unless group

    find_active_or_recent_record(group.id.to_s, question.id.to_s)
  end

  ##
  # Extracts the question text from the email subject and retrieves the matching Question record.
  #
  # The method splits the subject string using the '*' character, expecting the question text to be the portion
  # between the first pair of asterisks. It normalizes the extracted text by collapsing multiple whitespace characters
  # into a single space, then queries the Question model for a record whose normalized text exactly matches the extracted text.
  # Returns nil if no valid question text is found or if no matching record exists.
  #
  # @return [Question, nil] the matching Question record, or nil if no match is found.
  def find_question_from_subject
    question_parts = subject.split('*')
    question_text = question_parts[1]&.strip
    return nil unless question_text

    normalized_text = question_text.gsub(/\s+/, ' ').strip
    Question.where("trim(regexp_replace(question, '\\s+', ' ', 'g')) = ?", normalized_text).first
  end

  ##
  # Finds a group by extracting its name from the email subject.
  #
  # This method removes a leading "Re:" from the subject (if present), splits the cleaned subject at the first hyphen,
  # trims any surrounding whitespace from the resulting segment, and then attempts to locate a Group with that name.
  #
  # @return [Group, nil] The Group matching the extracted name, or nil if no valid group name is found.
  def find_group_from_subject
    clean_subject = subject.sub(/^Re:\s*/, '')
    group_name = clean_subject.split('-').first&.strip
    return nil unless group_name

    Group.find_by_name(group_name)
  end

  ##
  # Retrieves an active or recent question record for the specified group and question.
  #
  # This method first attempts to find an active record using
  # `QuestionRecord.find_active_record`. If none is found, it falls back to returning
  # the first result from `QuestionRecord.most_recent_for`, which represents the most
  # recent question record.
  #
  # @param group_id [Integer] Identifier for the group.
  # @param question_id [Integer] Identifier for the question.
  # @return [QuestionRecord, nil] The active or most recent question record, or nil if none exists.
  def find_active_or_recent_record(group_id, question_id)
    QuestionRecord.find_active_record(group_id, question_id) ||
      QuestionRecord.most_recent_for(group_id, question_id).first
  end

  ##
  # Marks the identification process as failed by setting the internal identification status.
  #
  # This method is invoked when none of the identification methods succeed, updating the internal
  # state to reflect the failure. It does not raise an error and always returns nil.
  #
  # @return [nil] Always returns nil.
  def handle_identification_failure
    @identification_method = "failed"
    nil
  end

  ##
  # Extracts and verifies the signed record ID from the reply-to email address.
  #
  # This method retrieves the recipient email address from the payload (considering the direct :to address,
  # the envelope's :to field, or :recipient) and attempts to extract a signed record identifier using the pattern
  # "reply+SIGNED_ID@domain.com". It then verifies the extracted signed ID with Rails' message verifier using the
  # "question_record" key. If the verification succeeds, the decoded record ID is returned; otherwise, if verification
  # fails or the recipient address is missing, the method returns nil and logs an "invalid_signature" event when applicable.
  #
  # @return [Object, nil] The decoded record ID if verification is successful; nil otherwise.
  def extract_record_id_from_reply_to
    # Check various places where the recipient address might be found
    envelope = params[:envelope] || {}
    to_address = params[:to] || envelope[:to] || params[:recipient]

    return nil unless to_address.present?

    # Extract the signed portion from reply+SIGNED_ID@domain.com format
    if to_address =~ /reply\+([^@]+)@/
      signed_id = Regexp.last_match(1)

      # Use Rails' built-in GlobalID signed ID verification
      begin
        decoded_id = Rails.application.message_verifier('question_record').verify(signed_id)
        return decoded_id
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        # Log invalid signatures
        log_event("invalid_signature", { to_address: to_address })
        return nil
      end
    end

    nil
  end

  ##
  # Extracts headers related to Answers2Answers from the email payload.
  #
  # This method scans the payload for headers starting with "X-Answers2Answers" (case-insensitive) at the root level.
  # It also inspects the "In-Reply-To" header to extract question and group IDs when they match specific patterns,
  # and merges any additional Answers2Answers headers found within a nested :headers hash.
  #
  # @return [Hash] A hash containing the extracted Answers2Answers headers.
  def extract_headers
    headers = {}
    # Use symbolized keys for params

    # Extract Answers2Answers headers from the root level
    params.each do |key, value|
      if key.to_s.start_with?('X-Answers2Answers') || key.to_s.start_with?('x-answers2answers')
        headers[key] = value
      end
    end

    # Check the In-Reply-To header
    in_reply_to = params[:"In-Reply-To"]
    if in_reply_to.present?
      if in_reply_to =~ /<question-(\d+)-group-(\d+)-user-(\d+)@/
        headers[:"X-Answers2Answers-QuestionId"] = Regexp.last_match(1)
        headers[:"X-Answers2Answers-GroupId"] = Regexp.last_match(2)
      elsif in_reply_to =~ /<weekly-question-(\d+)-group-(\d+)-user-(\d+)@/
        headers[:"X-Answers2Answers-QuestionId"] = Regexp.last_match(1)
        headers[:"X-Answers2Answers-GroupId"] = Regexp.last_match(2)
      end
    end

    # Check for headers within a :headers hash
    param_headers = params[:headers]
    if param_headers.is_a?(Hash)
      param_headers.each do |key, value|
        if key.to_s.start_with?('X-Answers2Answers')
          headers[key] = value
        end
      end
    end

    headers
  end

  ##
  # Checks if the replying user is an active member of the group associated with the question.
  #
  # @param user [User] the user attempting to reply.
  # @param question_record [QuestionRecord] the record linked to the question, from which the group is extracted.
  # @return [Boolean] true if the user is active in the group; false otherwise.
  def validate_recipient(user, question_record)
    # Get the group for this question record
    group = question_record.group

    # Check if user is a member of the group
    return user.active_in_group?(group)
  end

  ##
  # Logs a monitoring event and creates a corresponding Ahoy event record.
  #
  # This method enriches the provided properties with standard attributes such as the source identifier,
  # a truncated subject, a timestamp, and an inbound email identifier. It then logs the event using the Rails
  # logger and records it in the Ahoy analytics system with a namespaced event name.
  #
  # @param name [String] The event name.
  # @param properties [Hash] Optional event-specific properties. May include keys like :identification_method,
  #   :question_record_id, :user_id, :answer_id, or :cycle_status.
  #
  # @example
  #   log_event("answer.created", { user_id: 42, answer_id: 101 })
  #
  # Any errors during logging are caught and logged without disrupting the main service flow.
  def log_event(name, properties = {})
    # Add standard properties to all events
    event_properties = properties.slice(:identification_method, :question_record_id, :user_id, :answer_id, :cycle_status).merge({
      source: 'email_reply_service',
      subject: subject.truncate(100),
      timestamp: Time.current,
      inbound_email_id: inbound_email.id # Link event to the inbound email record
    })

    # Log to Rails logger with structured format for easier parsing
    Rails.logger.info("EmailReplyService: #{name} - #{event_properties.inspect}")

    # Create an Ahoy event directly
    Ahoy::Event.create(
      visit_id: nil,
      user_id: properties[:user_id],
      name: "email_reply.#{name}",
      properties: event_properties,
      time: Time.current
    )
  rescue => e
    # Ensure logging errors don't disrupt the main flow
    Rails.logger.error("Error logging email reply event for InboundEmail ##{inbound_email&.id}: #{e.message}")
  end
end