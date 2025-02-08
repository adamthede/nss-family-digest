class UsersController < ApplicationController
  before_action :set_user

  def show
    @questions = @user.questions
    @memberships = @user.memberships.includes(:group)
    @digest_counts = QuestionRecord.where(group_id: @user.groups.pluck(:id))
                                  .group(:group_id)
                                  .count
    @groups = Group.where(user_id: current_user)
  end

  def edit
  end

  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to user_path, notice: 'Your profile was successfully updated.' }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit }
        format.json { render json: @user.errors, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:email, :profile_image)
  end

end
