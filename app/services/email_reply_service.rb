class EmailReplyService
  attr_reader :params, :from_email, :subject, :content, :identification_method

  # Class method for processing an email reply
  def self.process_reply(params)
    new(params).process
  end

  def initialize(params)
    @params = params
    @from_email = extract_email
    @subject = params['subject'] || ''
    @raw_content = params['text'] || params['html'] || ""
    @content = extract_content
    @identification_method = nil
  end

  def process
    # Try to find the user first
    user = User.find_by_email(from_email)

    unless user
      log_event("no_user_found", { email: from_email })
      return { success: false, error: "No user found with email: #{from_email}" }
    end

    # Try different methods to identify the question record
    question_record = identify_question_record

    unless question_record
      log_event("question_record_not_found", {
        identification_method: identification_method || "failed",
        email: from_email,
        subject: subject
      })
      return { success: false, error: "Could not identify the question record" }
    end

    # Verify this email came from the user associated with the question
    unless validate_recipient(user, question_record)
      log_event("recipient_validation_failed", {
        user_id: user.id,
        question_record_id: question_record.id
      })
      return { success: false, error: "The email reply came from a user who was not a recipient of the question" }
    end

    # Check if the question is still in an active cycle
    cycle = QuestionCycle.find_by(question_record_id: question_record.id)

    unless cycle&.active?
      log_event("inactive_cycle", {
        identification_method: identification_method,
        question_record_id: question_record.id,
        cycle_status: cycle&.status
      })
      return { success: false, error: "The question is no longer accepting answers" }
    end

    # Create the answer
    answer = Answer.create(
      answer: content,
      user_id: user.id,
      question_record_id: question_record.id
    )

    if answer.persisted?
      log_event("answer_created", {
        identification_method: identification_method,
        question_record_id: question_record.id,
        answer_id: answer.id,
        user_id: user.id
      })
      return { success: true, answer: answer }
    else
      log_event("answer_creation_failed", {
        identification_method: identification_method,
        question_record_id: question_record.id,
        user_id: user.id,
        errors: answer.errors.full_messages
      })
      return { success: false, error: "Failed to create answer: #{answer.errors.full_messages.join(', ')}" }
    end
  end

  private

  # Extract the sender's email from various possible locations
  def extract_email
    if params['envelope']
      envelope = JSON.parse(params['envelope']) rescue {}
      return envelope['from'] if envelope['from'].present?
    end

    from_header = params['from']
    if from_header =~ /<(.+?)>/
      Regexp.last_match(1)
    else
      from_header
    end
  end

  # Extract and clean the content from the email
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
    # Method 1: Try to get the record ID from the signed reply-to
    record_id = extract_record_id_from_reply_to
    if record_id
      @identification_method = "signed_reply_to"
      record = QuestionRecord.find_by(id: record_id)
      return record if record
    end

    # Method 2: Try to get the record from headers
    headers = extract_headers
    if headers.present?
      @identification_method = "headers"

      group_id = headers['X-Answers2Answers-GroupId']
      question_id = headers['X-Answers2Answers-QuestionId']
      question_record_id = headers['X-Answers2Answers-QuestionRecordId']

      # Try to find by direct record ID first
      if question_record_id.present?
        record = QuestionRecord.find_by(id: question_record_id)
        return record if record

        # If record exists but not accepting answers, find another active one
        if group_id.present? && question_id.present?
          record = QuestionRecord.find_active_record(group_id, question_id)
          return record if record
        end
      elsif group_id.present? && question_id.present?
        # Try to find active record by group and question
        record = QuestionRecord.find_active_record(group_id, question_id)
        return record if record

        # Fall back to most recent
        record = QuestionRecord.most_recent_for(group_id, question_id).first
        return record if record
      end
    end

    # Method 3: Parse from subject (last resort)
    @identification_method = "subject_parsing"

    # Extract question text between asterisks
    if subject.include?('*')
      question_parts = subject.split('*')
      question_text = question_parts[1].strip if question_parts.length > 1

      # Look up the question
      question_obj = question_text ? Question.find_by_question(question_text) : nil
      return nil unless question_obj

      question_id = question_obj.id

      # Extract group name from the subject
      clean_subject = subject
      if clean_subject.start_with?('Re: ')
        clean_subject = clean_subject[4..-1] # Remove 'Re: ' prefix
      end

      # Try to get group name (everything before the dash)
      if clean_subject.include?('-')
        group_name = clean_subject.split('-').first.strip
        group = Group.find_by_name(group_name)

        if group
          # Try to find an active record first
          record = QuestionRecord.find_active_record(group.id, question_id)
          return record if record

          # Fall back to most recent
          record = QuestionRecord.most_recent_for(group.id, question_id).first
          return record if record
        end
      end
    end

    # If we get here, all identification methods failed
    @identification_method = "failed"
    nil
  end

  # Extract the signed record ID from the reply-to address
  def extract_record_id_from_reply_to
    # Check various places where the recipient address might be found
    to_address = params['to'] ||
                 (params['envelope'] && JSON.parse(params['envelope'])['to']) ||
                 params['recipient']

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

  # Extract email headers from the params
  def extract_headers
    headers = {}

    # Extract Answers2Answers headers from params
    params.each do |key, value|
      if key.to_s.start_with?('X-Answers2Answers') || key.to_s.start_with?('x-answers2answers')
        headers[key.to_s] = value
      end
    end

    # Check the In-Reply-To header for Message-ID references
    if params['In-Reply-To'].present?
      msg_id = params['In-Reply-To']
      if msg_id =~ /<question-(\d+)-group-(\d+)-user-(\d+)@/
        headers['X-Answers2Answers-QuestionId'] = Regexp.last_match(1)
        headers['X-Answers2Answers-GroupId'] = Regexp.last_match(2)
      elsif msg_id =~ /<weekly-question-(\d+)-group-(\d+)-user-(\d+)@/
        headers['X-Answers2Answers-QuestionId'] = Regexp.last_match(1)
        headers['X-Answers2Answers-GroupId'] = Regexp.last_match(2)
      end
    end

    # Check for headers in the headers hash
    if params['headers'].is_a?(Hash)
      params['headers'].each do |key, value|
        if key.to_s.start_with?('X-Answers2Answers')
          headers[key.to_s] = value
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
    properties.merge!({
      source: 'email_reply_service',
      subject: subject.truncate(100),
      timestamp: Time.current
    })

    # Log to Rails logger with structured format for easier parsing
    Rails.logger.info("EmailReplyService: #{name} - #{properties.inspect}")

    # Create an Ahoy event directly
    # This uses Ahoy's existing configuration without requiring changes to ahoy.rb
    event_properties = properties.slice(:identification_method, :question_record_id, :user_id, :answer_id, :cycle_status, :source)

    # Find a user if possible for proper tracking association
    user = properties[:user_id] ? User.find_by(id: properties[:user_id]) : nil

    # Create event with prefixed name to make filtering easier
    Ahoy::Event.create!(
      visit_id: nil,
      user_id: user&.id,
      name: "email_reply.#{name}",
      properties: event_properties,
      time: Time.current
    )
  rescue => e
    # Ensure logging errors don't disrupt the main flow
    Rails.logger.error("Error logging email reply event: #{e.message}")
  end
end