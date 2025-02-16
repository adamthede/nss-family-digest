class EmailResponseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def create_from_inbound_hook
    Rails.logger.info "Inbound email params: #{params.inspect}"

    from_param = params['from']
    from_email = extract_email(from_param)
    subject = params['subject']
    text_body = params['text'] || params['html'] || ""

    # Process the email with the cleaned email address.
    Answer.create_from_email(from_email, subject, text_body)

    head :ok, content_type: 'text/html'
  end

  private

  def extract_email(string)
    # Extracts the email address if present in angle brackets.
    if string =~ /<(.+?)>/
      Regexp.last_match(1)
    else
      string
    end
  end
end
