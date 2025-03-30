class GroupCyclesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group
  before_action :authorize_group_leader

  # GET /groups/:group_id/cycles
  def index
    # Calculate participation counts for sidebar display
    @participation_counts = Answer.joins(:question_record)
      .where(question_records: { group_id: @group.id })
      .group(:user_id)
      .distinct
      .count

    # Render the cycles view
    render template: 'groups/cycles'
  end

  # POST /groups/:group_id/cycles/send_manual_question
  def send_manual_question
    question = Question.find(params[:question_id])

    # Create a manual cycle
    cycle = @group.question_cycles.create!(
      question: question,
      start_date: Date.current,
      end_date: Date.current + 4.days,
      digest_date: Date.current + 5.days,
      status: 0, # scheduled
      manual: true
    )

    # Activate immediately
    cycle.activate!

    # Send emails
    @group.active_users.each do |user|
      QuestionMailer.weekly_question(user, @group, question).deliver_now
    end

    redirect_to group_cycles_path(@group), notice: 'Question sent successfully'
  end

  # POST /groups/:group_id/cycles/send_manual_digest/:cycle_id
  def send_manual_digest
    cycle = @group.question_cycles.find(params[:cycle_id])

    # Verify this is a valid cycle for digest
    unless cycle.status?(2) || cycle.status?("closed")
      redirect_to group_cycles_path(@group), alert: 'This question cycle is not ready for a digest'
      return
    end

    answers = cycle.question_record.answers

    if answers.empty?
      redirect_to group_cycles_path(@group), alert: 'No answers to send in digest'
      return
    end

    @group.active_users.each do |user|
      QuestionMailer.weekly_digest(user, @group, cycle.question, answers, cycle.question_record).deliver_now
    end

    cycle.complete!

    redirect_to group_cycles_path(@group), notice: 'Digest sent successfully'
  end

  # POST /groups/:group_id/cycles/pause
  def pause
    # Simply log all parameters to debug
    Rails.logger.debug "PAUSE ACTION: Params: #{params.inspect}"

    # Get the pause_until date from params
    date_param = params[:pause_until]
    Rails.logger.debug "PAUSE ACTION: Date param: #{date_param.inspect}"

    # Parse the date or use default
    if date_param.present?
      date = Date.parse(date_param)
    else
      date = Date.current + 30.days
    end

    Rails.logger.debug "PAUSE ACTION: Setting pause_until to #{date.inspect}"

    # Update the group
    @group.update!(paused_until: date)
    Rails.logger.debug "PAUSE ACTION: Group updated, paused_until now #{@group.reload.paused_until.inspect}"

    redirect_to group_cycles_path(@group), notice: "Automatic questions paused until #{date.strftime('%B %d, %Y')}"
  end

  # POST /groups/:group_id/cycles/resume
  def resume
    @group.resume_now
    redirect_to group_cycles_path(@group), notice: 'Automatic questions resumed'
  end

  # PATCH /groups/:group_id/cycles/update_mode
  def update_mode
    if params[:mode] == 'manual'
      @group.switch_to_manual_mode
      notice = 'Switched to manual question mode'
    else
      @group.switch_to_automatic_mode
      notice = 'Switched to automatic weekly questions'
    end

    redirect_to group_cycles_path(@group), notice: notice
  end

  # POST /groups/:group_id/cycles/:id/close_early
  def close_early
    cycle = @group.question_cycles.find(params[:id])

    # Debug the cycle status to see what's happening
    Rails.logger.debug "Cycle ID: #{cycle.id}, Status: #{cycle.status.inspect}, Is Active?: #{cycle.status == 'active'}"

    if cycle.status == 'active' || cycle.status == 1
      cycle.close!
      redirect_to group_cycles_path(@group), notice: 'Question cycle closed early. Answers are no longer being accepted.'
    else
      redirect_to group_cycles_path(@group), alert: "Only active cycles can be closed early. This cycle has status: #{cycle.status}"
    end
  end

  private

  def set_group
    @group = Group.find(params[:group_id])
  end

  def authorize_group_leader
    unless @group.leader?(current_user)
      redirect_to groups_path, alert: 'Only group leaders can manage question cycles'
    end
  end
end