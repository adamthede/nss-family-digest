class Answers
  def self.send!
    Answer.send_answer_digest
  end
end
