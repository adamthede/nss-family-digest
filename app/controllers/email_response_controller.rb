class EmailResponseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  REPLY_DELIMITER = "---- Reply Above This Line ----"

  ##
  # Processes an inbound email webhook payload.
  #
  # This method permits and logs the incoming payload, stores it in an InboundEmail
  # record with a status of "received", and triggers synchronous email reply processing via
  # EmailReplyService if the record is persisted successfully. In case of a persistence failure,
  # it logs an error indicating the validation issues but still returns an HTTP 200 response.
  #
  # @return [void] Always returns an HTTP 200 response with content type "text/html".
  def create_from_inbound_hook
    # Use permit! carefully, ensure SendGrid payload is trusted or filter params more strictly
    payload = params.permit!.to_h
    Rails.logger.info "Inbound email params: #{payload.inspect}"

    # Store the raw payload immediately
    inbound_email = InboundEmail.create(payload: payload, status: 'received')

    if inbound_email.persisted?
      # Process the email reply synchronously using the stored record
      EmailReplyService.process_reply(inbound_email)
    else
      Rails.logger.error "Failed to store inbound email payload: #{inbound_email.errors.full_messages.join(', ')}"
      # Optionally, notify admins or trigger monitoring here
    end

    # Always return success to the mail provider
    # Note: This response now waits for processing to complete
    head :ok, content_type: 'text/html'
  end

  # Remove private methods related to parsing, as they are now in the service
end
