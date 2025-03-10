class QuestionsController < ApplicationController
  before_action :set_question, only: [:show, :edit, :update, :destroy]

  # GET /questions
  # GET /questions.json
  def index
    @questions = Question.includes(:user).all
  end

  # GET /questions/1
  # GET /questions/1.json
  def show
  end

  # GET /questions/new
  def new
    @question = Question.new
  end

  # GET /questions/1/edit
  def edit
  end

  # POST /questions
  # POST /questions.json
  def create
    @question = current_user.questions.build(question_params)

    respond_to do |format|
      if @question.save
        format.html { redirect_to questions_path, notice: 'Question was successfully created.' }
        format.json { render :show, status: :created, location: @question }
      else
        format.html { render :new }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /questions/1
  # PATCH/PUT /questions/1.json
  def update
    respond_to do |format|
      if @question.update(question_params)
        format.html { redirect_to @question, notice: 'Question was successfully updated.' }
        format.json { render :show, status: :ok, location: @question }
      else
        format.html { render :edit }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /questions/1
  # DELETE /questions/1.json
  def destroy
    @question.destroy
    respond_to do |format|
      format.html { redirect_to questions_url, notice: 'Question was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def send_random_question
    group = Group.find(params[:group_id])

    # Get active users first
    active_users = group.active_users

    if active_users.empty?
      redirect_to group_path(group), alert: "No active members to send to"
      return
    end

    # Get a random question specific to this group
    question = Question.select_random_question(group)

    unless question
      redirect_to group_path(group), alert: "No questions available to send"
      return
    end

    begin
      # Ensure the question is in the group's library
      Group.add_question_to_group(group, question)

      # Create a question record for this sending event
      question_record = QuestionRecord.create!(
        group: group,
        question: question
      )

      # Only send to active users
      active_users.each do |user|
        QuestionMailer.send_questions(user, group, question.question).deliver_now
      end

      redirect_to group_path(group),
        notice: "Random question sent to #{active_users.count} active members!"
    rescue => e
      Rails.logger.error("Error sending random question: #{e.message}")
      redirect_to group_path(group),
        alert: "There was an error sending the question. Please try again later."
    end
  end

  # Send a specific question to a group
  def send_to_group
    @question = Question.find(params[:id])
    group = Group.find(params[:group_id])

    # Get active users
    active_users = group.active_users

    if active_users.empty?
      redirect_to group_path(group), alert: "No active members to send to"
      return
    end

    begin
      # Ensure the question is in the group's library (this is optional)
      # This will return the existing association if it exists
      Group.add_question_to_group(group, @question)

      # Create a new question record for this sending event
      # This allows the same question to be sent multiple times
      question_record = QuestionRecord.create!(
        group: group,
        question: @question
      )

      # Send to all active users
      active_users.each do |user|
        QuestionMailer.send_questions(user, group, @question.question).deliver_now
      end

      # Redirect back to the appropriate page
      redirect_back(
        fallback_location: group_path(group),
        notice: "Question sent to #{active_users.count} active members!"
      )
    rescue ActiveRecord::RecordInvalid => e
      if e.message.include?("Question has already been taken")
        # If the error is because the question is already in the library,
        # we can still create a question record and send the emails
        begin
          question_record = QuestionRecord.create!(
            group: group,
            question: @question
          )

          active_users.each do |user|
            QuestionMailer.send_questions(user, group, @question.question).deliver_now
          end

          redirect_back(
            fallback_location: group_path(group),
            notice: "Question sent to #{active_users.count} active members!"
          )
        rescue => inner_e
          Rails.logger.error("Error creating question record: #{inner_e.message}")
          redirect_back(
            fallback_location: group_path(group),
            alert: "There was an error sending the question. Please try again later."
          )
        end
      else
        # For other validation errors
        Rails.logger.error("Error sending question: #{e.message}")
        redirect_back(
          fallback_location: group_path(group),
          alert: "There was an error sending the question. Please try again later."
        )
      end
    rescue => e
      # Log the error and show a friendly message
      Rails.logger.error("Error sending question: #{e.message}")
      redirect_back(
        fallback_location: group_path(group),
        alert: "There was an error sending the question. Please try again later."
      )
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_question
      @question = Question.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def question_params
      params.require(:question).permit(:question)
    end
end
