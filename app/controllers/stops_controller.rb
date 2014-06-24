class StopsController < ApplicationController
  def stop_questions
    redirect_to group_path(params[:group_id]), notice: "The questioning has stopped!"
  end
end
