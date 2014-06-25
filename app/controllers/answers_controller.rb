class AnswersController < ApplicationController
  skip_before_filter  :verify_authenticity_token

  def create_from_inbound_hook
    message = params
    puts message
  end
end
