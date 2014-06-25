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

end
