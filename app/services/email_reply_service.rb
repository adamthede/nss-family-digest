class EmailReplyService
  attr_reader :inbound_email, :params, :from_email, :subject, :content, :identification_method

  # Class method for processing an email reply
  def self.process_reply(inbound_email)
    new(inbound_email).process
  end

  ##
  # Initializes an EmailReplyService instance by extracting essential details from the provided inbound email.
  #
  # This initializer deep-symbolizes the inbound email payload for consistent access and extracts key attributes,
  # including the sender's email, subject, and the raw and processed content. It also initializes the identification
  # method used later in processing.
  #
  # @param inbound_email [Object] The inbound email object containing the payload and associated metadata.
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
  # Processes the inbound email reply.
  #
  # This method updates the email status to "processing" and sequentially validates the user,
  # the associated question record, recipient eligibility, and the activeness of the question cycle.
  # If all checks pass, it attempts to create and save an answer; otherwise, it delegates to the appropriate
  # error handler. Any unexpected exceptions are caught and handled accordingly.
  #
  # @return [void]
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
  # Retrieves the User record associated with the sender's email.
  #
  # This method looks up and returns the user whose email matches the sender's email
  # extracted from the inbound email payload.
  #
  # @return [User, nil] the matching user record if found, otherwise nil.

  def find_and_validate_user
    User.find_by_email(from_email)
  end

  ##
  # Retrieves and validates the question record corresponding to the inbound email.
  #
  # Delegates to {#identify_question_record} to locate the relevant question record.
  # Returns the identified record if found; otherwise, returns nil.
  #
  # @return [QuestionRecord, nil] the validated question record or nil if not found.
  def find_and_validate_question_record
    identify_question_record
  end

  ##
  # Verifies that the given user is eligible to respond to the question by checking their membership
  # in the group associated with the question record.
  #
  # @param user [User] the user being validated as a potential respondent
  # @param question_record [QuestionRecord] the record representing the question to which the reply is related
  #
  # @return [Boolean] true if the user is a valid recipient; false otherwise
  def verify_recipient(user, question_record)
    validate_recipient(user, question_record)
  end

  ##
  # Returns the active question cycle associated with the given question record.
  #
  # This method retrieves the cycle linked to the question record using its ID and returns it only if it is active.
  #
  # @param question_record [Object] A record representing the question, expected to have an `id` attribute.
  # @return [QuestionCycle, nil] The active cycle if found; otherwise, nil.
  def verify_active_cycle(question_record)
    cycle = QuestionCycle.find_by(question_record_id: question_record.id)
    cycle if cycle&.active?
  end

  ##
  # Creates and saves a new answer using the provided user and question record.
  #
  # Constructs an Answer using the instance's content and associates it with the given user
  # and question record. If saving is successful, the method updates the inbound email status
  # to "processed", logs the creation event, and returns a success hash containing the new answer.
  # Otherwise, it delegates error handling to the answer creation failure handler.
  #
  # @param user [User] The user associated with the answer.
  # @param question_record [QuestionRecord] The question record linked to the answer.
  # @return [Hash{Symbol => Object}] A hash with a :success key and, if successful, an :answer key.
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
  # Handles the case when no user is found for the sender's email.
  #
  # This method updates the inbound email status to "failed" with an error message,
  # logs a "no_user_found" event with the sender's email, and returns a hash indicating
  # the failure.
  #
  # @return [Hash] A hash containing { success: false, error: error_message } where
  #   error_message is a string explaining that no user was found with the provided email.

  def handle_user_not_found
    error_msg = "No user found with email: #{from_email}"
    update_inbound_email(status: 'failed', notes: error_msg)
    log_event("no_user_found", { email: from_email })
    { success: false, error: error_msg }
  end

  ##
  # Handles the case when a question record cannot be identified.
  #
  # This method updates the inbound email by setting its status to 'failed' and recording a note that specifies
  # the identification method used (or 'unknown' if not available). It also logs an event named "question_record_not_found"
  # with details including the identification method (defaulting to "failed"), the sender's email, and the email subject.
  # Finally, it returns a hash indicating the failure.
  #
  # @return [Hash] A hash with keys:
  #   - :success [Boolean] Always false.
  #   - :error [String] The error message detailing the reason for the failure.
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
  # Handles the failure case when a recipient is not a valid active member of the group.
  #
  # Constructs an error message indicating that the sender's email (retrieved from an instance-specific
  # source) does not belong to an active group member for the given question record. It then updates the
  # inbound email status to "failed" with the error message, logs an event for monitoring purposes, and
  # returns a hash containing the failure status and error details.
  #
  # @param user [User] the user associated with the inbound email.
  # @param question_record [QuestionRecord] the question record containing group information.
  # @return [Hash{Symbol=>Object}] a hash with :success set to false and :error providing error details.
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
  # Handles the scenario where a question record is associated with an inactive cycle.
  #
  # Constructs an error message indicating that the question is no longer accepting answers due to an inactive or missing cycle,
  # updates the inbound email status to 'failed' with this message, logs the "inactive_cycle" event with pertinent details,
  # and returns a failure response hash containing the error message.
  #
  # @param question_record [Object] The question record being processed; must respond to `#id`.
  # @param cycle [Object, nil] The associated cycle instance; may be nil if no active cycle exists.
  # @return [Hash] A hash with `:success` set to false and `:error` containing the error message.
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
  # Handles a failure during answer creation by updating the inbound email status,
  # logging the failure event with relevant details, and returning an error response.
  #
  # @param answer [#errors] The answer object that failed creation; expected to respond to `errors.full_messages`.
  # @param user [User] The user who attempted to create the answer.
  # @param question_record [QuestionRecord] The record associated with the question for which the answer was attempted.
  # @return [Hash] A hash containing `:success` (false) and `:error` (a descriptive error message).
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
  # Handles unexpected errors encountered during email processing.
  #
  # Constructs a detailed error message including the error's message and the first five lines of its backtrace.
  # If an inbound email is present, it updates its status to 'failed' with the error details.
  # The error is then logged, and a hash indicating failure is returned.
  #
  # @param error [Exception] the error object that was raised
  # @return [Hash] a hash containing a success flag set to false and the detailed error message, e.g.,
  #   { success: false, error: "..." }
  def handle_unexpected_error(error)
    error_msg = "Unexpected error: #{error.message} - Backtrace: #{error.backtrace.first(5).join("\\n")}"
    # Ensure update happens even if inbound_email is nil, though unlikely
    update_inbound_email(status: 'failed', notes: error_msg) if @inbound_email
    Rails.logger.error error_msg
    # Optionally, notify admins here
    { success: false, error: error_msg }
  end

  ##
  # Updates the inbound email record by setting its status, processor notes, the processing timestamp, and optionally linking an answer.
  #
  # @param status [String] The new status to assign to the inbound email.
  # @param notes [String] Additional information regarding the update.
  # @param answer_id [Integer, nil] (optional) The identifier of the answer associated with the email.

  def update_inbound_email(status:, notes:, answer_id: nil)
    inbound_email.update(
      status: status,
      processor_notes: notes,
      processed_at: Time.current,
      answer_id: answer_id
    )
  end

  ##
  # Extracts the sender's email address from the inbound payload.
  #
  # This method first looks for an email address in the envelope hash's :from key using
  # symbolized keys. If not present there, it retrieves the email from the payload's :from field.
  # If this field contains an address formatted with a sender name (e.g., "Name <email@example.com>"),
  # the method extracts and returns only the email portion.
  #
  # @return [String, nil] the extracted email address, or nil if none is found.
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
  # Extracts and cleans the primary content from the raw email.
  #
  # This method checks if the raw email content contains a reply delimiter and,
  # if so, extracts the portion of the content before the delimiter. The extracted
  # content is then processed with EmailReplyParser to remove any quoted text,
  # resulting in clean reply content.
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
  # Attempts to identify the question record using multiple strategies in order of preference.
  #
  # This method sequentially invokes the following identification approaches:
  # - Identification by a signed reply-to address
  # - Identification via email headers
  # - Identification using the email subject
  #
  # If none of these methods return a valid question record, it calls a fallback handler to manage the failure.
  #
  # @return [QuestionRecord, nil] the identified question record if found; otherwise, the fallback result from the identification failure handler
  def identify_question_record
    # Try each identification method in order of preference
    identify_by_signed_reply_to ||
      identify_by_headers ||
      identify_by_subject ||
      handle_identification_failure
  end

  ##
  # Identifies a question record using a signed reply-to address.
  #
  # This method extracts a record ID from the reply-to address via
  # {#extract_record_id_from_reply_to}. If a record ID is found, it sets the identification
  # method to "signed_reply_to" and attempts to locate the corresponding {QuestionRecord}.
  # It returns the record if it exists and is accepting answers. If the record is not accepting
  # answers, the method extracts group and question IDs from the email envelope and,
  # if present, retrieves a suitable active or recent record using {#find_active_or_recent_record}.
  #
  # @return [QuestionRecord, nil] the identified question record if available and valid, or nil if not found.
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
  # Identifies the question record using email headers.
  #
  # This method extracts headers from the email payload, updates the internal
  # identification method to "headers", and attempts to locate an associated
  # question record. It first checks for a direct record ID provided via the
  # "X-Answers2Answers-QuestionRecordId" header and verifies if that record is
  # accepting answers. If not found, it then looks for group and question IDs
  # through the "X-Answers2Answers-GroupId" and "X-Answers2Answers-QuestionId"
  # headers to locate an active or recent record.
  #
  # @return [QuestionRecord, nil] the identified question record if it exists and
  #   is accepting answers; otherwise, nil.
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
  # Identifies a question record by parsing the email subject.
  #
  # This method checks if the subject contains a specific marker ("*"). If the marker is present, it sets the identification method to "subject_parsing", attempts to extract a question and its associated group from the subject, and returns the active or recent question record corresponding to the extracted group and question. If any step fails (i.e., the marker is absent or the extraction of the question or group fails), the method returns nil.
  #
  # @return [Object, nil] the active or recent question record if found, otherwise nil.
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
  # Extracts the question text from the subject and retrieves the corresponding Question record.
  #
  # This method splits the subject on asterisks (*), takes the second segment as the potential question text,
  # and normalizes its whitespace. It then performs an exact-match search on the Question records with the normalized text.
  #
  # @return [Question, nil] The first matching Question record if found, or nil if no valid question text is extracted.
  def find_question_from_subject
    question_parts = subject.split('*')
    question_text = question_parts[1]&.strip
    return nil unless question_text

    normalized_text = question_text.gsub(/\s+/, ' ').strip
    Question.where("trim(regexp_replace(question, '\\s+', ' ', 'g')) = ?", normalized_text).first
  end

  ##
  # Extracts and retrieves a Group from the email subject.
  #
  # This method removes the "Re:" prefix from the subject if present, splits the subject using '-' as a delimiter,
  # and trims the first segment to obtain the group name. It then queries for a Group with the matching name.
  #
  # @return [Group, nil] The matching Group if found, or nil if no valid group name is detected.
  def find_group_from_subject
    clean_subject = subject.sub(/^Re:\s*/, '')
    group_name = clean_subject.split('-').first&.strip
    return nil unless group_name

    Group.find_by_name(group_name)
  end

  ##
  # Finds an active question record or, if none exists, the most recent question record for the specified group and question.
  #
  # This method first attempts to retrieve an active question record. If no active record is found, it falls back to
  # returning the first entry from the most recent question records.
  #
  # @param group_id [Integer] Identifier of the group.
  # @param question_id [Integer] Identifier of the question.
  # @return [QuestionRecord, nil] The active or most recent question record, or nil if no record exists.
  def find_active_or_recent_record(group_id, question_id)
    QuestionRecord.find_active_record(group_id, question_id) ||
      QuestionRecord.most_recent_for(group_id, question_id).first
  end

  ##
  # Marks the identification process as failed.
  #
  # Sets the identification method indicator to "failed", signaling that no valid question record
  # could be identified during processing.
  def handle_identification_failure
    @identification_method = "failed"
    nil
  end

  ##
  # Extracts the signed record ID from the reply-to email address.
  #
  # This method retrieves the recipient address from the available parameters—checking keys such
  # as :to, :recipient, or the envelope's :to field—and looks for a signature token in the format
  # "reply+SIGNED_ID@domain.com". If a token is found, it attempts to decode and verify the signed
  # ID using Rails' message verifier for question records. If the signature is invalid or if no valid
  # recipient address is present, the method logs an "invalid_signature" event and returns nil.
  #
  # @return [Object, nil] the decoded record ID if the signature is valid, or nil otherwise.
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
  # Extracts Answers2Answers-related headers from the email payload.
  #
  # This method scans the payload for headers in three ways:
  # 1. It collects root-level keys starting with "X-Answers2Answers" (case insensitive).
  # 2. It inspects the "In-Reply-To" header for patterns that reveal question and group IDs.
  # 3. It examines a nested :headers hash for additional keys starting with "X-Answers2Answers".
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
  # Validates that the user is an active recipient of the question record.
  #
  # This method checks whether the given user is an active member of the group associated with
  # the provided question record.
  #
  # @param user [User] the user replying to the email.
  # @param question_record [QuestionRecord] the record containing the question and its associated group.
  # @return [Boolean] true if the user is active in the group; otherwise, false.
  def validate_recipient(user, question_record)
    # Get the group for this question record
    group = question_record.group

    # Check if user is a member of the group
    return user.active_in_group?(group)
  end

  ##
  # Logs a structured event for monitoring and analytics.
  #
  # This method augments the given event properties with standard metadata, including the
  # source identifier, a truncated subject, the current timestamp, and the associated inbound
  # email ID. It logs the event using the Rails logger and creates an Ahoy event for further
  # analysis. Any errors encountered during the logging process are caught and logged without
  # interrupting the main flow.
  #
  # @param name [String] The name of the event.
  # @param properties [Hash] Additional event properties. Recognized keys include
  #   :identification_method, :question_record_id, :user_id, :answer_id, and :cycle_status.
  # @return [void]
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