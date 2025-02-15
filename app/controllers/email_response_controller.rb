class EmailResponseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def create_from_inbound_hook
    Rails.logger.info "Inbound email params: #{params.inspect}"

    from = params['from']
    subject = params['subject']
    # Use 'text' field; use 'html' as a fallback if needed
    text_body = params['text'] || params['html']

    # Process the email (existing method call, update as needed)
    Answer.create_from_email(from, subject, text_body)

    head :ok, content_type: 'text/html'
  end

end
