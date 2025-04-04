class EmailReplyService
  attr_reader :inbound_email, :params, :from_email, :subject, :content, :identification_method

  # Class method for processing an email reply
  def self.process_reply(inbound_email)
    new(inbound_email).process
  end

  ##
  # Initializes the EmailReplyService instance with the provided inbound email.
  #
  # Extracts essential details from the email payload—including sender email, subject, and content—
  # while symbolizing payload keys for easier access. Applies default values when necessary
  # and sets the initial identification method to nil.
  #
  # @param inbound_email [Object] An object representing the inbound email; must respond to `payload` containing email details.
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
  # Processes an inbound email reply by validating the sender and question record before creating an answer.
  #
  # This method updates the inbound email status to "processing" and performs the following steps:
  # - Validates the sender by locating the corresponding user.
  # - Retrieves and validates the associated question record.
  # - Verifies that the user is an eligible recipient and that the question cycle is active.
  #
  # If any validation step fails, the corresponding error handler is invoked. On successful validation,
  # an answer is created and saved. Any unexpected errors during processing are caught and handled accordingly.
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
  # Retrieves the user associated with the sender's email.
  #
  # Searches for a user using the email stored in the `from_email` attribute.
  # Returns the matching user record if found, or nil otherwise.
  #
  # @return [User, nil] the user record corresponding to the sender's email, or nil if no match exists.

  def find_and_validate_user
    User.find_by_email(from_email)
  end

  ##
  # Finds and validates the question record associated with the inbound email.
  #
  # This method delegates to +identify_question_record+ to retrieve the question record
  # using various identification methods.
  #
  # @return [QuestionRecord, nil] the identified question record if valid, or +nil+ if not found
  def find_and_validate_question_record
    identify_question_record
  end

  ##
  # Verifies that the user is an eligible recipient for the specified question record.
  #
  # Delegates validation to ensure the user is an active member of the question's group.
  #
  # @param user [User] The user to validate.
  # @param question_record [QuestionRecord] The question record for which recipient eligibility is checked.
  def verify_recipient(user, question_record)
    validate_recipient(user, question_record)
  end

  ##
  # Determines if the given question record has an active cycle.
  #
  # Looks up the question cycle associated with the provided question record and returns it if it is active.
  #
  # @param question_record [QuestionRecord] The question record for which to verify an active cycle.
  # @return [QuestionCycle, nil] The active cycle if it exists, otherwise nil.
  def verify_active_cycle(question_record)
    cycle = QuestionCycle.find_by(question_record_id: question_record.id)
    cycle if cycle&.active?
  end

  ##
  # Creates and persists an answer associated with a user and a question record.
  #
  # Instantiates a new answer using the service's content and links it to the provided user and question record. If the answer is saved successfully, the method updates the inbound email status to "processed", logs the creation event, and returns a hash indicating success along with the answer. If saving fails, it delegates error handling to manage the failure.
  #
  # @param user [User] the user submitting the answer.
  # @param question_record [QuestionRecord] the question record to which the answer belongs.
  # @return [Hash{Symbol=>Object}] a hash containing a success flag and the answer instance, or the result of the failure handler if saving fails.
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
  # Handles the case where no user is found for the provided sender's email.
  #
  # This method creates an error message incorporating the sender's email, updates the
  # inbound email's status to "failed" with the error message, and logs an event indicating
  # that no user was found. It returns a hash representing the failure, with a boolean flag
  # and the error message.
  #
  # @return [Hash] a hash containing:
  #   - :success [Boolean] always false
  #   - :error [String] the error message describing the missing user

  def handle_user_not_found
    error_msg = "No user found with email: #{from_email}"
    update_inbound_email(status: 'failed', notes: error_msg)
    log_event("no_user_found", { email: from_email })
    { success: false, error: error_msg }
  end

  ##
  # Handles the error case when a question record cannot be identified.
  #
  # Constructs an error message based on the available identification method, updates the inbound email status
  # to "failed" with the error details, logs an event for tracking purposes, and returns a hash indicating failure.
  #
  # @return [Hash] A hash containing:
  #   - :success [Boolean] Always false, indicating the operation failed.
  #   - :error [String]  The error message describing the failure.
  #
  # @example
  #   result = handle_question_record_not_found
  #   # => { success: false, error: "Could not identify the question record using method: unknown" }
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
  # Handles a recipient validation failure by updating the email status, logging the failure,
  # and returning an error hash.
  #
  # When an email sender is determined not to be an active member of the question record's group,
  # this method sets the inbound email status to 'failed' with a corresponding error message,
  # logs a "recipient_validation_failed" event with relevant user and question record IDs,
  # and returns a hash indicating the failure.
  #
  # @param user [User] the user associated with the inbound email.
  # @param question_record [QuestionRecord] the question record being validated.
  # @return [Hash] a hash with a success flag set to false and an error message describing the failure.
  #
  # @example
  #   result = handle_recipient_validation_failed(user, question_record)
  #   # => { success: false, error: "Recipient validation failed: Email from user@example.com is not an active member of group 123." }
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
  # Handles the scenario where a question is no longer accepting answers due to an inactive cycle.
  #
  # This method constructs an error message using the provided question record and cycle information,
  # updates the inbound email status to "failed" with the error notes, logs an "inactive_cycle" event,
  # and returns a hash indicating the failure along with the error message.
  #
  # @param question_record [Object] The question record associated with the email reply.
  # @param cycle [Object, nil] The cycle related to the question; may be nil if not applicable.
  # @return [Hash] A hash with keys:
  #   - :success [Boolean] Always false.
  #   - :error [String] The error message describing the inactive cycle condition.
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
  # Handles a failure during answer creation.
  #
  # This method retrieves validation error messages from the provided answer object, updates the inbound email status to 'failed' with the error details, and logs an event capturing the failure along with the associated question record and user IDs.
  #
  # @param answer [Object] The answer instance with failed validations (expected to expose error messages via `errors.full_messages`).
  # @param user [User] The user for whom the answer creation failed.
  # @param question_record [Question] The question record associated with the failed answer.
  #
  # @return [Hash] A hash containing:
  #   - :success [Boolean] Always false.
  #   - :error [String] A concatenated error message detailing the validation issues.
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
  # Handles an unexpected error during email processing by logging the error,
  # updating the inbound email status to 'failed' (if available), and returning a
  # failure response.
  #
  # @param error [Exception] The exception that was raised.
  # @return [Hash] A hash containing a failure status and the error message.
  def handle_unexpected_error(error)
    error_msg = "Unexpected error: #{error.message} - Backtrace: #{error.backtrace.first(5).join("\\n")}"
    # Ensure update happens even if inbound_email is nil, though unlikely
    update_inbound_email(status: 'failed', notes: error_msg) if @inbound_email
    Rails.logger.error error_msg
    # Optionally, notify admins here
    { success: false, error: error_msg }
  end

  ##
  # Updates the associated inbound email record with processing details.
  #
  # This method sets the email's new status, logs processor notes, records the current time as when the email was processed,
  # and optionally associates an answer via its identifier.
  #
  # @param status [String] the updated status of the inbound email (e.g., 'processed', 'failed').
  # @param notes [String] additional notes regarding the processing outcome.
  # @param answer_id [Integer, nil] an optional identifier for the associated answer.

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
  # The method first checks for an envelope hash with a :from value. If found, it returns that email.
  # Otherwise, it retrieves the top-level :from field and extracts an email address enclosed within angle
  # brackets if present.
  #
  # @return [String, nil] The sender's email address, or nil if it cannot be extracted.
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
  # Extracts and cleans the email reply content.
  #
  # This method processes the raw email content by checking for a reply delimiter, which indicates the beginning of quoted text. If the delimiter is found, only the content preceding it is retained. The selected content is then cleaned using EmailReplyParser to remove any residual quoted text artifacts.
  #
  # @return [String] The processed and cleaned email reply content.
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
  # Identifies the question record associated with the email reply by using several heuristics.
  #
  # This method attempts to locate the question record by first checking a signed reply-to address,
  # then examining email headers, and finally analyzing the subject line. If none of these methods
  # yield a valid record, it delegates the failure handling to the appropriate procedure.
  #
  # @return [Object, nil] The identified question record if found, or the result of the failure handler otherwise.
  def identify_question_record
    # Try each identification method in order of preference
    identify_by_signed_reply_to ||
      identify_by_headers ||
      identify_by_subject ||
      handle_identification_failure
  end

  ##
  # Attempts to identify a question record using a signed reply-to address.
  #
  # This method extracts a record ID from the reply-to header. If a record ID is found, it assigns "signed_reply_to" as the identification method and fetches the corresponding question record. It returns the record only if it exists and is currently accepting answers. If the record is not accepting answers, the method extracts group and question identifiers from the envelope's recipient information and attempts to locate an active or recent question record.
  #
  # @return [QuestionRecord, nil] The valid question record ready to receive answers or nil if none is found.
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
  # Identifies a question record from the inbound email headers.
  #
  # Extracts relevant headers from the inbound email and attempts to determine the 
  # associated question record. It first checks for a direct record ID in the 
  # "X-Answers2Answers-QuestionRecordId" header and verifies if the record is accepting answers.
  # If that approach does not yield a valid record, it falls back to using the group and
  # question IDs from the "X-Answers2Answers-GroupId" and "X-Answers2Answers-QuestionId" headers 
  # to find an active or recent question record.
  #
  # @return [QuestionRecord, nil] The identified question record if available; otherwise, nil.
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
  # This method checks whether the subject contains an asterisk (*) to determine if subject parsing should be applied.
  # If the marker is present, it updates the identification method, attempts to extract both the question and group
  # information from the subject, and retrieves an active or recent record that matches the identified group and question.
  # It returns nil if the subject lacks the marker or if either the question or group cannot be determined.
  #
  # @return [Object, nil] the active or recent question record if found, or nil otherwise.
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
  # Extracts and normalizes the question text from the email subject, then returns the first matching Question record.
  #
  # The subject is split using the asterisk (*) delimiter, and the text between the delimiters is cleaned by condensing whitespace.
  # The method queries the Question model for a record with a question field matching this normalized text.
  # If the subject does not include valid question text, the method returns nil.
  #
  # @return [Question, nil] the matching Question record if found, or nil otherwise
  def find_question_from_subject
    question_parts = subject.split('*')
    question_text = question_parts[1]&.strip
    return nil unless question_text

    normalized_text = question_text.gsub(/\s+/, ' ').strip
    Question.where("trim(regexp_replace(question, '\\s+', ' ', 'g')) = ?", normalized_text).first
  end

  ##
  # Extracts and returns the group associated with the email subject.
  #
  # This method removes a leading "Re:" prefix from the subject and extracts the segment before the first hyphen,
  # trimming any extraneous whitespace. It then searches for a group with the extracted name using the Group model.
  # Returns nil if no valid group name is found or if the group does not exist.
  #
  # @return [Group, nil] the group matching the extracted name, or nil if not found.
  def find_group_from_subject
    clean_subject = subject.sub(/^Re:\s*/, '')
    group_name = clean_subject.split('-').first&.strip
    return nil unless group_name

    Group.find_by_name(group_name)
  end

  ##
  # Retrieves an active question record from the given group and question identifiers.
  #
  # This method first attempts to find an active record. If none exists, it returns the most recent
  # record associated with the provided group and question IDs. Returns nil if no record is found.
  #
  # @param group_id [Integer] Identifier for the group associated with the question.
  # @param question_id [Integer] Identifier for the question.
  # @return [QuestionRecord, nil] The active or most recent question record, or nil if no record is found.
  def find_active_or_recent_record(group_id, question_id)
    QuestionRecord.find_active_record(group_id, question_id) ||
      QuestionRecord.most_recent_for(group_id, question_id).first
  end

  ##
  # Records that the attempt to identify the corresponding question record has failed.
  #
  # This method sets the internal identification status to "failed", indicating
  # that the system was unable to determine the appropriate question record.
  #
  # @return [nil]
  def handle_identification_failure
    @identification_method = "failed"
    nil
  end

  ##
  # Extracts and decodes a signed record ID from the reply-to email address.
  #
  # This method retrieves the recipient address from the available parameters and checks
  # if it follows the expected format (e.g., "reply+SIGNED_ID@domain.com"). If a signed ID is
  # found, it is verified using Rails' message verifier associated with "question_record".
  # If the signature is invalid or the recipient address is missing, an "invalid_signature"
  # event is logged and nil is returned.
  #
  # @return [Object, nil] The decoded record ID if verification succeeds, or nil otherwise.
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
  # Extracts Answers2Answers-related headers from the inbound email payload.
  #
  # This method scans the main parameters and a nested :headers hash for headers whose names
  # start with "X-Answers2Answers" (case-insensitive). It also inspects the "In-Reply-To" header
  # for patterns that include question and group identifiers, extracting them into the returned hash.
  #
  # @return [Hash] A hash of extracted headers with symbolized keys.
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
  # Checks if the replying user is an active member of the group associated with the provided question record.
  #
  # Validates that the user is eligible to reply by ensuring their active membership in the group tied to the question.
  #
  # @param user [User] the individual sending the reply.
  # @param question_record [QuestionRecord] the record containing the question and its associated group.
  # @return [Boolean] true if the user is an active member of the group; false otherwise.
  #
  # @example
  #   if validate_recipient(user, question_record)
  #     # Proceed with processing the reply
  #   else
  #     # Handle the case for an invalid recipient
  #   end
  def validate_recipient(user, question_record)
    # Get the group for this question record
    group = question_record.group

    # Check if user is a member of the group
    return user.active_in_group?(group)
  end

  ##
  # Logs a structured event for tracking email reply processing.
  #
  # This method merges optional event properties with default metadata—such as the event source,
  # a truncated email subject, the current timestamp, and the inbound email ID—to create a consistent
  # event payload. It logs the event using Rails' logger for immediate monitoring and also creates an
  # Ahoy event record for analytics. Any errors encountered during this process are caught and logged,
  # ensuring that event logging does not disrupt the primary flow.
  #
  # @param name [String] The identifier for the event.
  # @param properties [Hash] Optional additional properties (e.g., identification method, question 
  #   record ID, user ID, answer ID, cycle status) to include with the event.
  #
  # @example
  #   log_event("reply_received", { user_id: 1, question_record_id: 2 })
  #   # Logs the event and creates a corresponding Ahoy event.
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