class GroupsController < ApplicationController
  before_action :set_group, only: [:show, :edit, :update, :destroy, :questions, :digests]

  # GET /groups
  # GET /groups.json
  def index
    @groups = Group.all
  end

  # GET /groups/1
  # GET /groups/1.json
  def show
    # Calculate participation counts for each user (needed for both tabs)
    @participation_counts = Answer.joins(:question_record)
      .where(question_records: { group_id: @group.id })
      .group(:user_id)
      .distinct
      .count

    # Redirect to the appropriate tab action
    if params[:tab] == 'questions'
      redirect_to questions_group_path(@group, request.query_parameters.except(:tab))
    else
      redirect_to digests_group_path(@group, request.query_parameters.except(:tab))
    end
  end

  # GET /groups/1/digests
  def digests
    # Calculate participation counts for each user
    @participation_counts = Answer.joins(:question_record)
      .where(question_records: { group_id: @group.id })
      .group(:user_id)
      .distinct
      .count

    # Q&A Digests tab
    base_query = @group.question_records
      .includes(:question, :answers)

    # Apply sorting for Q&A Digests
    @question_records = case params[:sort]
    when 'date_asc'
      base_query.order(created_at: :asc)
    when 'answers_desc'
      base_query
        .select('question_records.*, COUNT(DISTINCT answers.id) as answers_count')
        .left_joins(:answers)
        .group('question_records.id')
        .order(Arel.sql('COUNT(DISTINCT answers.id) DESC, question_records.created_at DESC'))
    when 'answers_asc'
      base_query
        .select('question_records.*, COUNT(DISTINCT answers.id) as answers_count')
        .left_joins(:answers)
        .group('question_records.id')
        .order(Arel.sql('COUNT(DISTINCT answers.id) ASC, question_records.created_at DESC'))
    else # 'date_desc' or default
      base_query.order(created_at: :desc)
    end

    # Load questions for display
    @questions = Question.where(id: @question_records.pluck(:question_id)).index_by(&:id)

    # Get answer counts
    @answer_counts = Answer.where(question_record_id: @question_records.pluck(:id))
      .group(:question_record_id)
      .count

    respond_to do |format|
      format.html { render :show }
      format.turbo_stream if request.xhr?
    end
  end

  # GET /groups/1/questions
  def questions
    # Calculate participation counts for each user
    @participation_counts = Answer.joins(:question_record)
      .where(question_records: { group_id: @group.id })
      .group(:user_id)
      .distinct
      .count

    # Load questions with all necessary associations
    @questions = Question.includes(:tags, group_question_tags: [:tag, :created_by])

    # Get voting information for questions in this group
    @group_questions = @group.group_questions.includes(:group_question_votes)
    @group_questions_by_id = @group_questions.index_by(&:question_id)

    # Calculate usage counts
    @question_usage_counts = @group.question_records
      .group(:question_id)
      .count

    # Apply filters
    if params[:filter] == 'used'
      @questions = @questions.where(id: @question_usage_counts.keys)
    elsif params[:filter] == 'unused'
      @questions = @questions.where.not(id: @question_usage_counts.keys)
    end

    # Apply tag filtering
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
      @questions.sort_by { |q| -(@group_questions_by_id[q.id]&.vote_count || 0) }
    when 'usage'
      @questions.sort_by { |q| -(@question_usage_counts[q.id] || 0) }
    else # 'newest' or default
      @questions.order(created_at: :desc)
    end

    respond_to do |format|
      format.html { render :show }
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
        # Create an active membership for the group leader
        @group.memberships.create!(user: current_user, active: true)

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
    emails = params[:emails].split(',').map(&:strip)

    successful_invites = []
    failed_invites = []

    emails.each do |email|
      user = User.find_or_create_by_email(email)

      # Check if membership already exists
      existing_membership = @group.memberships.find_by(user: user)

      if existing_membership
        if existing_membership.active?
          failed_invites << "#{email} is already an active member"
        elsif existing_membership.pending?
          failed_invites << "#{email} already has a pending invitation"
        else
          # Reactivate and resend invitation for inactive memberships
          existing_membership.update!(
            active: false,
            invitation_token: SecureRandom.urlsafe_base64(32),
            invitation_accepted_at: nil
          )
          GroupMailer.invite_email(user.email, @group.id, existing_membership.invitation_token).deliver_now
          successful_invites << email
        end
        next
      end

      # Create new membership
      begin
        membership = @group.memberships.create!(
          user: user,
          active: false
        )
        GroupMailer.invite_email(user.email, @group.id, membership.invitation_token).deliver_now
        successful_invites << email
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid => e
        failed_invites << "#{email} could not be invited (#{e.message})"
      end
    end

    # Set flash messages
    if successful_invites.any?
      flash[:notice] = "Invitations sent to: #{successful_invites.join(', ')}"
    end

    if failed_invites.any?
      flash[:alert] = failed_invites.join(', ')
    end

    redirect_to group_path(@group)
  end

  # Add new method to handle invitation acceptance
  def accept_invitation
    membership = Membership.find_by!(invitation_token: params[:token])

    # Check if user is signed in
    unless current_user
      # Store invitation token in session for post-login processing
      session[:pending_invitation_token] = params[:token]

      # Redirect to sign in with a return path
      return redirect_to new_user_session_path,
        notice: "Please sign in or set up your account to accept the invitation"
    end

    # Ensure the invitation belongs to the current user
    unless membership.user == current_user
      return redirect_to root_path,
        alert: "This invitation was sent to a different email address"
    end

    if membership.pending?
      membership.accept_invitation!
      flash[:notice] = "Welcome to #{membership.group.name}!"
    else
      flash[:alert] = "This invitation is no longer valid"
    end

    redirect_to group_path(membership.group)
  end

  def toggle_member_status
    @group = Group.find(params[:id])
    @member = User.find(params[:member_id])

    if @group.leader?(current_user)
      active_status = params[:active].to_s == 'true'
      @group.toggle_member_status!(@member, active_status, current_user)

      action = active_status ? "activated" : "deactivated"
      flash[:notice] = "Member #{@member.email} has been #{action}"
    else
      flash[:alert] = "Only group leaders can manage member status"
    end

    redirect_to group_path(@group)
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