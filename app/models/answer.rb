class Answer < ApplicationRecord
  belongs_to :question_record
  belongs_to :user

  has_rich_text :answer

  validates_presence_of :user
  validates_presence_of :question_record

  validate :answer_present?

  def self.create_from_inbound_hook(message)
    puts message
    # self.new(:text => message["TextBody"],
    #          :user_email => message["From"],
    #          :discussion_id => message["MailboxHash"])
  end

  def self.create_from_email(from, subject, textbody)
    if (user = User.find_by_email(from.to_s))
      question = subject.split('*').last.strip
      question_id = Question.find_by_question(question).id.to_s
      groupname = subject.split('-').first.strip
      group = Group.find_by_name(groupname[4..-1])
      group_id = group.id.to_s
      question_record = QuestionRecord.where(:group_id => group_id, :question_id => question_id).last
      question_record_id = question_record.id.to_s
      if DateTime.now < question_record.created_at + 5.days
        Answer.create(:answer => textbody,
                      :user_id => user.id,
                      :question_record_id => question_record_id)
      else
        logger.info("TOO LATE!  Answering has closed for this question.")
      end
    else
      logger.info("No user found with email: #{from.to_s}")
    end
  end

  def self.send_answer_digest
    start_date = 7.days.ago
    end_date = DateTime.now
    question_record = QuestionRecord.where(:created_at => start_date..end_date)
    question_record.each do |record|
      group_id = record.group_id
      question_id = record.question_id
      group = Group.find(group_id)
      question = Question.find(question_id)
      answers = Answer.where(question_record_id: record.id)
      group.users.each do |user|
        QuestionMailer.weekly_digest(user, group, question, answers, record).deliver
      end
    end
  end

  private

  def answer_present?
    return if answer.present? || read_attribute(:answer).present?
    errors.add(:answer, "can't be blank")
  end

end
