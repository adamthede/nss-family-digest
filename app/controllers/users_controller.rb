class UsersController < ApplicationController

  def show
    @user = User.find(params[:id])
    @questions = @user.questions
    @groups = @user.groups
  end

  def edit
  end
  
end
