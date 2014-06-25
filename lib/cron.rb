class Cron
  def self.run!
    Question.send_question
  end
end
