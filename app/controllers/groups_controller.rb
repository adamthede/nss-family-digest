class GroupsController < ApplicationController
  before_action :set_group, only: [:show, :edit, :update, :destroy]

  # GET /groups
  # GET /groups.json
  def index
    @groups = Group.all
  end

  # GET /groups/1
  # GET /groups/1.json
  def show
    @group = Group.find(params[:id])

    # Get base query for question records
    @question_records = QuestionRecord.where(group_id: @group.id)

    # Get answer counts for sorting
    @answer_counts = Answer.where(question_record_id: @question_records.pluck(:id))
                          .group(:question_record_id)
                          .count

    # Apply sorting
    case params[:sort]
    when 'answers_desc'
      @question_records = @question_records.sort_by { |record| -(@answer_counts[record.id] || 0) }
    when 'answers_asc'
      @question_records = @question_records.sort_by { |record| @answer_counts[record.id] || 0 }
    when 'date_asc'
      @question_records = @question_records.order(created_at: :asc)
    else # date_desc by default
      @question_records = @question_records.order(created_at: :desc)
    end

    # Preload questions to avoid N+1 queries
    @questions = Question.where(id: @question_records.pluck(:question_id))
                        .index_by(&:id)

    # Calculate participation counts for each user
    @participation_counts = Answer.joins(:question_record)
      .where(question_records: { group_id: @group.id })
      .group(:user_id)
      .distinct
      .count
  end

  # GET /groups/new
  def new
    @group = Group.new
  end

  # GET /groups/1/edit
  def edit
  end

  # POST /groups
  # POST /groups.json
  def create
    @group = current_user.groups.build(group_params)
    respond_to do |format|
      if @group.save
        @group.users << current_user
        format.html { redirect_to @group, notice: 'Group was successfully created.' }
        format.json { render :show, status: :created, location: @group }
      else
        format.html { render :new }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /groups/1
  # PATCH/PUT /groups/1.json
  def update
    respond_to do |format|
      if @group.update(group_params)
        format.html { redirect_to @group, notice: 'Group was successfully updated.' }
        format.json { render :show, status: :ok, location: @group }
      else
        format.html { render :edit }
        format.json { render json: @group.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /groups/1
  # DELETE /groups/1.json
  def destroy
    @group.destroy
    respond_to do |format|
      format.html { redirect_to groups_url, notice: 'Group was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def send_invite
    @group = Group.find(params[:group_id])

    emails = params[:emails].split(',').map!{ |e| e.strip }

    emails.each do |email|
      user = User.find_or_create_by_email(email)
      GroupMailer.invite_email(user.email, @group.id).deliver
      @group.users << user
    end

    redirect_to group_path(@group.id), notice: "Your invites have been sent!"
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_group
    @group = Group.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def group_params
    params.require(:group).permit(:name, :id)
  end
end
