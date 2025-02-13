class ApplicationMailer < ActionMailer::Base
  default from: ENV['DEFAULT_MAILER_FROM'] || 'noreply@example.com'
  layout 'mailer'

  # Add message history tracking
  has_history

  # Add UTM tagging
  utm_params

  # Add click tracking with a campaign
  track_clicks campaign: -> { "#{mailer_name}-#{action_name}" }
end
