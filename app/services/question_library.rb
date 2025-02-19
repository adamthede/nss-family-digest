class QuestionLibrary
  def initialize(group, params = {})
    @group = group
    @params = params
  end

  def questions
    Rails.cache.fetch(cache_key) do
      load_questions
        .then { |q| filter_by_usage(q) }
        .then { |q| filter_by_tag(q) }
        .then { |q| sort_questions(q) }
    end
  end

  def usage_counts
    @usage_counts ||= @group.question_records
      .group(:question_id)
      .count
  end

  def group_questions
    @group_questions ||= @group.group_questions
      .includes(:group_question_votes)
      .index_by(&:question_id)
  end

  private

  def load_questions
    Question.includes(:tags, group_question_tags: [:tag, :created_by])
  end

  def filter_by_usage(questions)
    questions.filter_by_usage(@group, @params[:filter])
  end

  def filter_by_tag(questions)
    if @params[:tag].present?
      questions.filter_by_tag(@params[:tag], @group.id)
    else
      questions
    end
  end

  def sort_questions(questions)
    case @params[:sort]
    when 'votes'
      questions.with_votes_in_group(@group).order('vote_count DESC')
    when 'usage'
      questions.with_usage_in_group(@group).order('usage_count DESC')
    else
      questions.order(created_at: :desc)
    end
  end

  def cache_key
    "question_library/#{@group.id}/#{@params.to_json}"
  end
end