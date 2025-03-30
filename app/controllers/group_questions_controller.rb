class GroupQuestionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_group
  before_action :authorize_group_leader

  # Send a manual question
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
      QuestionMailer.weekly_question(user, @group, question).deliver_later
    end

    redirect_to cycles_group_path(@group), notice: 'Question sent successfully'
  end

  # Send digest for a manual question
  def send_manual_digest
    cycle = @group.question_cycles.find(params[:cycle_id])

    # Verify this is a valid cycle for digest
    unless cycle.status?(2) || cycle.status?("closed")
      redirect_to cycles_group_path(@group), alert: 'This question cycle is not ready for a digest'
      return
    end

    answers = cycle.question_record.answers

    if answers.empty?
      redirect_to cycles_group_path(@group), alert: 'No answers to send in digest'
      return
    end

    @group.active_users.each do |user|
      QuestionMailer.weekly_digest(user, @group, cycle.question, answers, cycle.question_record).deliver_later
    end

    cycle.complete!

    redirect_to cycles_group_path(@group), notice: 'Digest sent successfully'
  end

  # Pause automatic cycles
  def pause_cycles
    date = params[:pause_until].present? ? Date.parse(params[:pause_until]) : (Date.current + 30.days)
    @group.pause_until(date)
    redirect_to cycles_group_path(@group), notice: "Automatic questions paused until #{date.strftime('%B %d, %Y')}"
  end

  # Resume automatic cycles
  def resume_cycles
    @group.resume_now
    redirect_to cycles_group_path(@group), notice: 'Automatic questions resumed'
  end

  # Switch between automatic and manual modes
  def update_question_mode
    if params[:mode] == 'manual'
      @group.switch_to_manual_mode
      notice = 'Switched to manual question mode'
    else
      @group.switch_to_automatic_mode
      notice = 'Switched to automatic weekly questions'
    end

    redirect_to cycles_group_path(@group), notice: notice
  end

  private

  def set_group
    @group = Group.find(params[:group_id] || params[:id])
  end

  def authorize_group_leader
    unless @group.leader?(current_user)
      redirect_to groups_path, alert: 'Only group leaders can manage questions'
    end
  end
end