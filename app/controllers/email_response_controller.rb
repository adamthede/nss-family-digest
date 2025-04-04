class EmailResponseController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  REPLY_DELIMITER = "---- Reply Above This Line ----"

  ##
  # Processes an inbound email hook by persisting the raw email payload and initiating reply processing.
  #
  # The method extracts all parameters from the request (using `permit!`), logs the payload,
  # and creates an `InboundEmail` record with a status of 'received'. If the record is successfully persisted,
  # it synchronously processes the email reply through the `EmailReplyService`. Otherwise, an error is logged
  # with the validation issues. Regardless of the outcome, the method always responds with an HTTP 200 OK status,
  # ensuring the mail provider receives a successful acknowledgment.
  #
  # Note: Use of `permit!` assumes that the payload is trusted (e.g., originating from a service like SendGrid).
  #
  # @return [void] Sends an HTTP 200 OK response with a text/html content type.
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
