class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception

  before_action :authenticate_user!

  after_action :track_action

  protected

  def track_action
    ahoy.track "#{controller_name}##{action_name}", request.path_parameters
  end
end
