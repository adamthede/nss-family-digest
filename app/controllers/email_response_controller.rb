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

    # Extract headers from params
    headers = extract_headers(params)

    # Pass headers to create_from_email method
    Answer.create_from_email(from_email, subject, new_content, headers)
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
