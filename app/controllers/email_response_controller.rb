class EmailResponseController < ApplicationController
  # skip_before_filter  :verify_authenticity_token
  skip_before_action :authenticate_user!

  def create_from_inbound_hook

  end

end
