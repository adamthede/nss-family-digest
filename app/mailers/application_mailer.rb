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
  # Generates a unique message ID by combining a type with optional identifiers.
  #
  # This method builds a consistent message ID by starting with the provided type and appending key-value pairs from the
  # given hash where each value is present. The final message ID is wrapped in angle brackets and includes the application
  # domain, taken from the 'APP_DOMAIN' environment variable or defaulting to 'answers2answers.app'.
  #
  # @param type [String] The primary identifier for the message.
  # @param ids [Hash] A hash of additional identifiers; only entries with present values are included.
  # @return [String] A formatted message ID in the format "<type-key1-value1-key2-value2@domain>".
  #
  # @example Generate a message ID using only a type:
  #   generate_message_id("mail")
  #   # => "<mail@answers2answers.app>"
  #
  # @example Generate a message ID with a type and additional IDs:
  #   generate_message_id("notification", { user: 42, order: 100 })
  #   # => "<notification-user-42-order-100@answers2answers.app>"
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
  # Adds application-specific headers to the email message.
  #
  # Iterates over a provided hash of identifiers and adds each as a custom header by prefixing
  # the CamelCased key with "X-Answers2Answers-". The header is only added if the corresponding
  # value is present.
  #
  # @param ids [Hash] A hash of identifier keys and their corresponding values.
  #
  # @example
  #   add_app_headers(user_id: 123, campaign_id: 'spring_sale')
  def add_app_headers(ids = {})
    # Add each ID as a separate header
    ids.each do |key, value|
      headers["X-Answers2Answers-#{key.to_s.camelize}"] = value.to_s if value.present?
    end
  end

  # Generate a secure reply-to address with a signed ID
  ##
  # Generates a secure reply-to email address with an embedded signed record identifier.
  #
  # This method creates a reply-to email address that securely encodes the provided
  # record ID within its local-part. It derives the base email from the SENDGRID_INBOUND
  # environment variable (or defaults to "reply@answers2answers.app"), and then uses
  # Rails' message verifier to generate a signed token (valid for 30 days) from the record ID.
  # The resulting reply-to address is formatted as "reply+signed_id@domain.com".
  #
  # @param record_id The identifier to be signed and embedded for secure reply tracking.
  # @return [String] A secure reply-to email address in the format "reply+signed_id@domain.com".
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
