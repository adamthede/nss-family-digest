class ApplicationMailer < ActionMailer::Base
  default from: ENV['DEFAULT_MAILER_FROM'] || 'noreply@example.com'
  layout 'mailer'

  # Add message history tracking
  has_history

  # Add UTM tagging
  utm_params

  # Add click tracking with a campaign
  track_clicks campaign: -> { "#{mailer_name}-#{action_name}" }

  REPLY_DELIMITER = "---- Reply Above This Line ----"

  ##
  # Generates a unique message ID for email headers.
  #
  # Constructs a message identifier by combining a provided type with additional 
  # identifier components from the given hash. Only non-blank values are included; 
  # each is appended in a "key-value" format. The final ID is enclosed in angle brackets 
  # and suffixed with a domain specified by the APP_DOMAIN environment variable or defaults 
  # to 'answers2answers.app'.
  #
  # @param type [String] The primary category for the message ID.
  # @param ids [Hash] Optional key-value pairs to append as additional identifiers.
  # @return [String] The formatted message identifier.
  def generate_message_id(type, ids = {})
    components = ["#{type}"]

    # Add all provided IDs to the message ID
    ids.each do |key, value|
      components << "#{key}-#{value}" if value.present?
    end

    # Create a unique message ID
    "<#{components.join('-')}@#{ENV['APP_DOMAIN'] || 'answers2answers.app'}>"
  end

  ##
  # Adds standard application headers to the email.
  #
  # Iterates through each key-value pair in the provided hash and, if the value is present,
  # sets a corresponding header on the email. The header key is formed by camelizing the key
  # and prefixing it with "X-Answers2Answers-".
  #
  # @param ids [Hash] A hash of header identifiers and their values to include in the email headers.
  def add_app_headers(ids = {})
    # Add each ID as a separate header
    ids.each do |key, value|
      headers["X-Answers2Answers-#{key.to_s.camelize}"] = value.to_s if value.present?
    end
  end

  # Generate a secure reply-to address with a signed ID
  ##
  # Generates a secure reply-to email address for tracking email replies.
  #
  # Constructs a reply-to address by appending a signed token (generated using Rails'
  # message verifier with a 30-day expiration) to the local part of a base email address.
  # The base email is sourced from the SENDGRID_INBOUND environment variable or defaults
  # to "reply@answers2answers.app". The resulting address follows the format "local+signed_id@domain".
  #
  # @param record_id [Object] Identifier for the record to sign for reply tracking.
  # @return [String] Secure reply-to email address.
  #
  # @example
  #   secure_reply_to(123)
  #   # => "reply+<signed_token>@answers2answers.app"
  def secure_reply_to(record_id)
    base_email = ENV['SENDGRID_INBOUND'] || 'reply@answers2answers.app'
    email_parts = base_email.split('@')

    # Generate a signed ID using Rails' built-in message verifier
    # This is more secure than our custom implementation
    signed_id = Rails.application.message_verifier('question_record').generate(record_id, expires_in: 30.days)

    # Create reply-to in format: reply+signed_id@domain.com
    "#{email_parts[0]}+#{signed_id}@#{email_parts[1]}"
  end
end
