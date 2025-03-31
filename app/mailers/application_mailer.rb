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

  # Helper method to generate consistent message IDs
  def generate_message_id(type, ids = {})
    components = ["#{type}"]

    # Add all provided IDs to the message ID
    ids.each do |key, value|
      components << "#{key}-#{value}" if value.present?
    end

    # Create a unique message ID
    "<#{components.join('-')}@#{ENV['APP_DOMAIN'] || 'answers2answers.app'}>"
  end

  # Helper to add standard application headers to all messages
  def add_app_headers(ids = {})
    # Add each ID as a separate header
    ids.each do |key, value|
      headers["X-Answers2Answers-#{key.to_s.camelize}"] = value.to_s if value.present?
    end
  end

  # Generate a secure reply-to address with a signed ID
  # This is more reliable than using headers for reply tracking
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
