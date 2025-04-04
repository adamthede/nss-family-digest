class EmailReplyService
  attr_reader :inbound_email, :params, :from_email, :subject, :content, :identification_method

  # Class method for processing an email reply
  def self.process_reply(inbound_email)
    new(inbound_email).process
  end

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

  # --- Main Process Steps --- #

  def find_and_validate_user
    User.find_by_email(from_email)
  end

  def find_and_validate_question_record
    identify_question_record
  end

  def verify_recipient(user, question_record)
    validate_recipient(user, question_record)
  end

  # Returns the cycle if active, otherwise nil
  def verify_active_cycle(question_record)
    cycle = QuestionCycle.find_by(question_record_id: question_record.id)
    cycle if cycle&.active?
  end

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

  # --- Failure Handling & Response Methods --- #

  def handle_user_not_found
    error_msg = "No user found with email: #{from_email}"
    update_inbound_email(status: 'failed', notes: error_msg)
    log_event("no_user_found", { email: from_email })
    { success: false, error: error_msg }
  end

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

  def handle_recipient_validation_failed(user, question_record)
    error_msg = "Recipient validation failed: Email from #{from_email} is not an active member of group #{question_record.group_id}."
    update_inbound_email(status: 'failed', notes: error_msg)
    log_event("recipient_validation_failed", {
      user_id: user.id,
      question_record_id: question_record.id
    })
    { success: false, error: error_msg }
  end

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

  def handle_unexpected_error(error)
    error_msg = "Unexpected error: #{error.message} - Backtrace: #{error.backtrace.first(5).join("\\n")}"
    # Ensure update happens even if inbound_email is nil, though unlikely
    update_inbound_email(status: 'failed', notes: error_msg) if @inbound_email
    Rails.logger.error error_msg
    # Optionally, notify admins here
    { success: false, error: error_msg }
  end

  # --- Existing Private Utility Methods --- #

  def update_inbound_email(status:, notes:, answer_id: nil)
    inbound_email.update(
      status: status,
      processor_notes: notes,
      processed_at: Time.current,
      answer_id: answer_id
    )
  end

  # Extract the sender's email from various possible locations in the payload
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

  # Extract and clean the content from the email payload
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

  # Identify the question record using multiple methods, with fallbacks
  def identify_question_record
    # Try each identification method in order of preference
    identify_by_signed_reply_to ||
      identify_by_headers ||
      identify_by_subject ||
      handle_identification_failure
  end

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

  def identify_by_subject
    return nil unless subject.include?('*')

    @identification_method = "subject_parsing"

    question = find_question_from_subject
    return nil unless question

    group = find_group_from_subject
    return nil unless group

    find_active_or_recent_record(group.id.to_s, question.id.to_s)
  end

  def find_question_from_subject
    question_parts = subject.split('*')
    question_text = question_parts[1]&.strip
    return nil unless question_text

    normalized_text = question_text.gsub(/\s+/, ' ').strip
    Question.where("trim(regexp_replace(question, '\\s+', ' ', 'g')) = ?", normalized_text).first
  end

  def find_group_from_subject
    clean_subject = subject.sub(/^Re:\s*/, '')
    group_name = clean_subject.split('-').first&.strip
    return nil unless group_name

    Group.find_by_name(group_name)
  end

  def find_active_or_recent_record(group_id, question_id)
    QuestionRecord.find_active_record(group_id, question_id) ||
      QuestionRecord.most_recent_for(group_id, question_id).first
  end

  def handle_identification_failure
    @identification_method = "failed"
    nil
  end

  # Extract the signed record ID from the reply-to address in the payload
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

  # Extract email headers from the payload
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

  # Validate that the user replying is a recipient of the question
  def validate_recipient(user, question_record)
    # Get the group for this question record
    group = question_record.group

    # Check if user is a member of the group
    return user.active_in_group?(group)
  end

  # Log events for monitoring and metrics
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