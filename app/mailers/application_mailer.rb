class ApplicationMailer < ActionMailer::Base
  default from: ENV['DEFAULT_MAILER_FROM'] || 'noreply@example.com'
  layout 'mailer'

  include Ahoy::Messages::Tracking

  track click: true, open: true, message: true
  after_action :track_email

  private

  def track_email
    ahoy_message.save_message
  end
end
