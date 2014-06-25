class AnswersController < ApplicationController
  skip_before_filter  :verify_authenticity_token
  
  def process_inbound_email(email)
    puts email
  end
end
