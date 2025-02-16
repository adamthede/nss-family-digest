class EmailResponseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def create_from_inbound_hook
    Rails.logger.info "Inbound email params: #{params.inspect}"

    from_email = extract_email(params)
    subject    = params['subject']
    text_body  = params['text'] || params['html'] || ""

    # Extract only the reply part authored by the user.
    new_content = EmailReplyParser.parse_reply(text_body)

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
