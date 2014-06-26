class Answer < ActiveRecord::Base
  belongs_to :question_record
  belongs_to :user

  validates_presence_of :answer

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
      answer = Answer.new(:answer => textbody,
                 :user_id => user.id,
                 :question_records_id => question_record_id)
      if Answer.where(answer)
        return
      else
        answer.save
      end
    else
      logger.info("No user found with email: #{from.to_s}")
    end
  end

end
