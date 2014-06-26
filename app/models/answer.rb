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
    answer = Answer.create do |answer|
      answer.answer = textbody
      answer.user_id = User.where(email: from).id
      answer.question_records_id = 7
    end
  end

end
