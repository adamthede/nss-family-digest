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

    Answer.create_from_email(from_email, subject, new_content)
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
end
