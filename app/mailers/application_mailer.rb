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
  # This method constructs the message ID by concatenating the provided type with any
  # additional identifiers from the hash. Each key-value pair is appended only if its value
  # is present, formatted as "key-value". The complete ID is wrapped in angle brackets and
  # uses the application domain from the 'APP_DOMAIN' environment variable, defaulting to
  # 'answers2answers.app' if not set.
  #
  # @param type [String] A string representing the type or category for the message ID.
  # @param ids [Hash] A hash of additional identifiers to include in the message ID. Non-present
  #   values are excluded.
  # @return [String] A formatted unique message ID in the form "<type-key1-value1-…@domain>"
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
  # Adds standard application headers to outgoing email messages.
  #
  # Iterates over the provided hash of IDs and adds each non-empty value as a header,
  # using a key prefixed with "X-Answers2Answers-" followed by the CamelCase version of the original key.
  #
  # @param ids [Hash] A mapping of header identifiers to their corresponding values.
  #
  # @example Adding headers to an email
  #   add_app_headers(order_id: 123, user_id: 456)
  #   # Sets:
  #   # headers["X-Answers2Answers-OrderId"] = "123"
  #   # headers["X-Answers2Answers-UserId"] = "456"
  def add_app_headers(ids = {})
    # Add each ID as a separate header
    ids.each do |key, value|
      headers["X-Answers2Answers-#{key.to_s.camelize}"] = value.to_s if value.present?
    end
  end

  # Generate a secure reply-to address with a signed ID
  ##
  # Generates a secure reply-to email address that includes a signed identifier.
  #
  # This method constructs the reply-to address by appending a signed version of
  # the provided record ID (with a 30-day expiration) to the base email's local part.
  # The base email is determined by the SENDGRID_INBOUND environment variable or falls back to
  # 'reply@answers2answers.app'. The resulting address follows the format:
  # "local_part+signed_id@domain".
  #
  # @param record_id [Object] The record's identifier used for generating the signed token.
  # @return [String] The secure reply-to email address.
  #
  # @example
  #   secure_reply_to(123) #=> "reply+signed_token@answers2answers.app"
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
