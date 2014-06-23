class GroupMembershipController < ApplicationController
  before_action :set_group_membership

  def update
    respond_to do |format|
      if @group_membership.update(group_params)
        format.html { redirect_to @group, notice: 'Group was successfully updated.' }
        format.json { render :show, status: :ok, location: @group }
      else
        format.html { render :edit }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @group_membership.destroy
    respond_to do |format|
      format.html { redirect_to groups_url, notice: 'Group was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_group_membership
    @group_membership = GroupMembership.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def group_membership_params
    params.require(:group).permit(:name)
  end

end
