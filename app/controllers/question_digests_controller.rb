class QuestionDigestsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group
  before_action :authorize_group_leader, except: [:show]
  before_action :set_digest, only: [:show, :destroy, :send_digest]

  def index
    @digests = @group.question_digests.order(created_at: :desc)
  end

  def show
    @question_records = @digest.question_records.includes(:question, :answers)
  end

  def new
    @digest = QuestionDigest.new
  end

  def create
    start_date = params[:question_digest][:start_date]
    end_date = params[:question_digest][:end_date]

    service = DigestGeneratorService.new(@group, start_date, end_date)

    if service.generate
      redirect_to group_question_digest_path(@group, service.instance_variable_get(:@digest)),
                  notice: "Digest was successfully created."
    else
      @digest = QuestionDigest.new
      flash.now[:alert] = service.errors.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def send_digest
    service = DigestDeliveryService.new(@digest)

    if service.deliver
      redirect_to group_question_digest_path(@group, @digest),
                  notice: "Digest emails have been queued for delivery."
    else
      redirect_to group_question_digest_path(@group, @digest),
                  alert: "Failed to send digest emails: #{service.errors.join(', ')}"
    end
  end

  def destroy
    @digest.destroy
    redirect_to group_question_digests_path(@group), notice: "Digest was successfully deleted."
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def set_digest
    @digest = @group.question_digests.find(params[:id])
  end

  def authorize_group_leader
    unless current_user == @group.leader
      redirect_to group_path(@group), alert: "Only the group leader can manage digests."
    end
  end
end