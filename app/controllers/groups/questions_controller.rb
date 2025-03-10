module Groups
  class QuestionsController < ApplicationController
    before_action :set_group
    before_action :set_question

    def show
      # Get usage statistics
      @usage_count = @group.question_records.where(question_id: @question.id).count

      # Get all instances this question was asked
      @question_records = @group.question_records
        .where(question_id: @question.id)
        .order(created_at: :desc)

      # Simple total answers count
      @total_answers = Answer.where(question_record_id: @question_records.pluck(:id)).count

      # Get voting information
      @group_question = @group.group_questions.find_by(question: @question)
      @voter_count = @group_question&.group_question_votes&.count || 0

      # Get similar questions based on tags
      @similar_questions = Question.joins(:tags)
        .where(tags: { id: @question.tags.pluck(:id) })
        .where.not(id: @question.id)
        .distinct
        .limit(5)
    end

    def add_tag
      # Ensure user is a member of the group
      unless @group.users.include?(current_user)
        redirect_to group_question_path(@group, @question), alert: "Only group members can add tags"
        return
      end

      tag = Tag.find_or_create_by(name: params[:tag_name].strip.downcase)

      unless @question.group_question_tags.exists?(group: @group, tag: tag)
        @question.group_question_tags.create!(
          group: @group,
          tag: tag,
          created_by: current_user  # Track who created the tag
        )
      end

      @question.reload

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to group_question_path(@group, @question) }
      end
    end

    def remove_tag
      # Only group leaders can remove tags
      unless current_user == @group.leader
        redirect_to group_question_path(@group, @question), alert: "Only group leaders can remove tags"
        return
      end

      tag = Tag.find(params[:tag_id])
      group_tag = @question.group_question_tags.find_by(group: @group, tag: tag)
      group_tag&.destroy

      @question.reload

      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to group_question_path(@group, @question) }
      end
    end

    def vote
      @group_question = @group.group_questions.find_or_create_by!(question: @question)

      if @group_question.voted_by?(current_user)
        redirect_back(fallback_location: group_question_path(@group, @question), alert: "You have already voted for this question")
        return
      end

      vote = @group_question.group_question_votes.build(user: current_user)

      if vote.save
        respond_to do |format|
          format.turbo_stream {
            render turbo_stream: [
              turbo_stream.replace("vote-button-area-#{@group_question.id}",
                partial: 'groups/questions/vote_button_area',
                locals: { group: @group, question: @question, group_question: @group_question }
              ),
              turbo_stream.replace_all(".question-#{@question.id}-vote-count",
                @group_question.vote_count.to_s)
            ]
          }
          format.html { redirect_back(fallback_location: group_question_path(@group, @question), notice: "Vote recorded") }
        end
      else
        redirect_back(fallback_location: group_question_path(@group, @question), alert: vote.errors.full_messages.to_sentence)
      end
    end

    def unvote
      @group_question = @group.group_questions.find_by!(question: @question)
      vote = @group_question.group_question_votes.find_by(user: current_user)

      if vote&.destroy
        respond_to do |format|
          format.turbo_stream {
            render turbo_stream: [
              turbo_stream.replace("vote-button-area-#{@group_question.id}",
                partial: 'groups/questions/vote_button_area',
                locals: { group: @group, question: @question, group_question: @group_question }
              ),
              turbo_stream.replace_all(".question-#{@question.id}-vote-count",
                @group_question.vote_count.to_s)
            ]
          }
          format.html { redirect_back(fallback_location: group_question_path(@group, @question), notice: "Vote removed") }
        end
      else
        redirect_back(fallback_location: group_question_path(@group, @question), alert: "Unable to remove vote")
      end
    end

    private

    def set_group
      @group = Group.find(params[:group_id])
    end

    def set_question
      @question = Question.find(params[:id])
    end
  end
end