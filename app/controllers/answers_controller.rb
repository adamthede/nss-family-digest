class AnswersController < ApplicationController
  skip_before_filter  :verify_authenticity_token

  def self.create_from_inbound_hook
    message = params
    self.new(:text => message["TextBody"],
             :user_email => message["From"],
             :discussion_id => message["MailboxHash"])
  end
end
