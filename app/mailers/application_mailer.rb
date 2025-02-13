class ApplicationMailer < ActionMailer::Base
  default from: ENV['DEFAULT_MAILER_FROM'] || 'noreply@example.com'
  layout 'mailer'

  # Add message history tracking
  has_history

  # Add UTM tagging
  utm_params

  # Add click tracking with a campaign
  track_clicks campaign: -> { "#{mailer_name}-#{action_name}" }

  include Ahoy::Messages::Tracking

  track click: true, open: true, message: true
  after_action :track_email

  private

  def track_email
    ahoy_message.save_message
  end
end
