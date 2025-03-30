class Answer < ApplicationRecord
  belongs_to :question_record
  belongs_to :user

  has_rich_text :answer

  validates_presence_of :user
  validates_presence_of :question_record

  validate :answer_present?
  validate :answer_within_valid_period

  def self.create_from_email(from, subject, textbody)
    if (user = User.find_by_email(from.to_s))
      question = subject.split('*').last.strip
      question_id = Question.find_by_question(question).id.to_s
      groupname = subject.split('-').first.strip
      group = Group.find_by_name(groupname[4..-1])
      group_id = group.id.to_s
      question_record = QuestionRecord.where(:group_id => group_id, :question_id => question_id).last
      question_record_id = question_record.id.to_s

      # Check if question is in an active cycle
      cycle = QuestionCycle.find_by(question_record_id: question_record_id)
      if cycle && cycle.status == 'active'
        Answer.create(:answer => textbody,
                      :user_id => user.id,
                      :question_record_id => question_record_id)
      else
        logger.info("INVALID CYCLE STATUS: Answering has closed for this question.")
      end
    else
      logger.info("No user found with email: #{from.to_s}")
    end
  end

  private

  def answer_present?
    return if answer.present? || read_attribute(:answer).present?
    errors.add(:answer, "can't be blank")
  end

  def answer_within_valid_period
    # Get the question cycle
    cycle = QuestionCycle.find_by(question_record_id: question_record_id)

    if cycle && cycle.status != 'active'
      errors.add(:base, "The question is no longer accepting answers")
    end
  end
end
