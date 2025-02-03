class ApplicationMailer < ActionMailer::Base
  default from: ENV['DEFAULT_MAILER_FROM'] || 'noreply@example.com'
  layout 'mailer'
end
