class EmailResponseController < ApplicationController
  skip_before_filter  :verify_authenticity_token
  skip_before_action :authenticate_user!

  def create_from_inbound_hook
    puts params
    from = params[:From]
    puts from
    subject = params[:Subject]
    puts subject
    textbody = params[:TextBody]
    puts textbody
    Answer.create_from_email(from, subject, textbody)
    head :ok, :content_type => 'text/html'
  end

end
