class EmailResponseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  REPLY_DELIMITER = "---- Reply Above This Line ----"

  def create_from_inbound_hook
    Rails.logger.info "Inbound email params: #{params.inspect}"

    from_email = extract_email(params)
    subject    = params['subject']

    # Get the raw text portion.
    raw_text = params['text'] || params['html'] || ""

    # If present, split at the custom delimiter.
    new_content = if raw_text.include?(REPLY_DELIMITER)
                    raw_text.split(REPLY_DELIMITER).first
                  else
                    raw_text
                  end

    # Further process the text to remove common quoting, if needed.
    new_content = EmailReplyParser.parse_reply(new_content)

    # Extract the question record ID from the reply-to address if available
    question_record_id = extract_record_id_from_reply_to(params)

    # If we have a direct question_record_id from reply-to, use it
    if question_record_id.present?
      create_answer_from_record_id(from_email, new_content, question_record_id)
    else
      # Fall back to headers or subject parsing if no record ID found
      headers = extract_headers(params)
      Answer.create_from_email(from_email, subject, new_content, headers)
    end

    head :ok, content_type: 'text/html'
  end

  private

  def extract_email(params)
    # Try to parse the 'envelope' attribute for a clean sender email.
    if params['envelope']
      envelope = JSON.parse(params['envelope']) rescue {}
      return envelope['from'] if envelope['from'].present?
    end

    # Fallback to extracting from the 'from' header
    from_header = params['from']
    if from_header =~ /<(.+?)>/
      Regexp.last_match(1)
    else
      from_header
    end
  end

  # Extract and verify the question record ID from a signed reply-to address
  def extract_record_id_from_reply_to(params)
    # Check various places where the recipient address might be found
    to_address = params['to'] ||
                 (params['envelope'] && JSON.parse(params['envelope'])['to']) ||
                 params['recipient']

    return nil unless to_address.present?

    # Extract the signed portion from reply+SIGNED_ID@domain.com format
    if to_address =~ /reply\+([^@]+)@/
      signed_data = Regexp.last_match(1)

      # Verify and extract the record ID from the signed data
      verify_signed_id(signed_data)
    else
      nil
    end
  end

  # Verify the signed ID and return the record ID if valid
  def verify_signed_id(signed_data)
    parts = signed_data.split('-')
    return nil unless parts.size >= 3

    record_id = parts[0]
    expiration = parts[1].to_i
    provided_signature = parts.last

    # Check if the signature has expired
    return nil if Time.now.to_i > expiration

    # Regenerate the signature to verify
    secret = Rails.application.secret_key_base[0..32]
    data = "#{record_id}-#{expiration}"
    expected_signature = OpenSSL::HMAC.hexdigest('SHA256', secret, data)

    # Compare signatures to verify authenticity
    if provided_signature == expected_signature
      record_id.to_i
    else
      Rails.logger.warn("Invalid signature detected in reply-to address")
      nil
    end
  end

  # Create an answer directly when we have a verified question record ID
  def create_answer_from_record_id(from_email, content, question_record_id)
    if (user = User.find_by_email(from_email.to_s))
      question_record = QuestionRecord.find_by(id: question_record_id)

      if question_record
        # Check if in active cycle
        cycle = QuestionCycle.find_by(question_record_id: question_record.id)
        if cycle && cycle.status_active?
          answer = Answer.create(
            answer: content,
            user_id: user.id,
            question_record_id: question_record.id
          )
          Rails.logger.info("Created answer from signed reply-to: #{answer.id}")
          return answer
        else
          Rails.logger.info("Question cycle no longer active for record: #{question_record_id}")
        end
      else
        Rails.logger.warn("Could not find question record: #{question_record_id}")
      end
    else
      Rails.logger.info("No user found with email: #{from_email}")
    end
    nil
  end

  def extract_headers(params)
    headers = {}

    # Extract all Answers2Answers headers
    params.each do |key, value|
      # Handle email provider specific header formats
      if key.to_s.start_with?('X-Answers2Answers') || key.to_s.start_with?('x-answers2answers')
        headers[key.to_s] = value
      end
    end

    # Extract headers from the References or In-Reply-To headers
    if params['In-Reply-To'].present?
      # Try to extract IDs from Message-ID format
      msg_id = params['In-Reply-To']
      if msg_id =~ /<question-(\d+)-group-(\d+)-user-(\d+)@/
        headers['X-Answers2Answers-QuestionId'] = Regexp.last_match(1)
        headers['X-Answers2Answers-GroupId'] = Regexp.last_match(2)
      elsif msg_id =~ /<weekly-question-(\d+)-group-(\d+)-user-(\d+)@/
        headers['X-Answers2Answers-QuestionId'] = Regexp.last_match(1)
        headers['X-Answers2Answers-GroupId'] = Regexp.last_match(2)
      end
    end

    # Check for headers in a headers hash if the email service provides it
    if params['headers'].is_a?(Hash)
      params['headers'].each do |key, value|
        if key.to_s.start_with?('X-Answers2Answers')
          headers[key.to_s] = value
        end
      end
    end

    headers
  end
end
