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
    user = User.find_by_email(from.to_s)
    Answer.create(:answer => textbody,
               :user_id => user.id,
               :question_records_id => 1)
  end

end
