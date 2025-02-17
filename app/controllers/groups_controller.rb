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

    # Calculate participation counts for each user (needed for both tabs)
    @participation_counts = Answer.joins(:question_record)
      .where(question_records: { group_id: @group.id })
      .group(:user_id)
      .distinct
      .count

    if params[:tab] == 'questions'
      # Load all questions with their tags
      @questions = Question.includes(:tags, :group_question_tags)

      # Calculate how many times each question has been used in this group
      @question_usage_counts = @group.question_records
        .group(:question_id)
        .count

      # Get voting information for questions in this group
      @group_questions_by_question = @group.group_questions
        .includes(:group_question_votes)
        .index_by(&:question_id)

      # Apply filters
      if params[:filter] == 'used'
        @questions = @questions.where(id: @question_usage_counts.keys)
      elsif params[:filter] == 'unused'
        @questions = @questions.where.not(id: @question_usage_counts.keys)
      end

      # Apply tag filtering if present
      if params[:tag].present?
        tag_id = params[:tag]
        @questions = @questions.where(
          'questions.id IN (SELECT question_id FROM question_tags WHERE tag_id = ?) OR ' \
          'questions.id IN (SELECT question_id FROM group_question_tags WHERE tag_id = ? AND group_id = ?)',
          tag_id, tag_id, @group.id
        )
      end

      # Apply sorting
      @questions = case params[:sort]
      when 'votes'
        @questions.sort_by { |q| -(@group_questions_by_question[q.id]&.vote_count || 0) }
      when 'usage'
        @questions.sort_by { |q| -(@question_usage_counts[q.id] || 0) }
      else # 'newest' or default
        @questions.order(created_at: :desc)
      end
    else
      # Existing digest tab logic
      @questions = Question.where(id: @group.question_records.pluck(:question_id)).index_by(&:id)

      # Get question records without initial ordering
      @question_records = @group.question_records

      # Get answer counts first
      @answer_counts = Answer.where(question_record_id: @question_records.pluck(:id))
                            .group(:question_record_id)
                            .count

      # Calculate how many times each question has been asked
      @question_usage_counts = @group.question_records
        .group(:question_id)
        .count

      # Then apply sorting
      case params[:sort]
      when 'answers_desc'
        @question_records = @question_records.sort_by { |record| -(@answer_counts[record.id] || 0) }
      when 'answers_asc'
        @question_records = @question_records.sort_by { |record| @answer_counts[record.id] || 0 }
      when 'date_asc'
        @question_records = @question_records.order(created_at: :asc)
      when 'date_desc'
        @question_records = @question_records.order(created_at: :desc)
      else # date_desc by default
        @question_records = @question_records.order(created_at: :desc)
      end

      # Preload questions to avoid N+1 queries
      @questions = Question.where(id: @question_records.pluck(:question_id))
                          .index_by(&:id)
    end

    respond_to do |format|
      format.html
      format.turbo_stream if request.xhr?
    end
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
