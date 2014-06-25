class QuestionMailer < ActionMailer::Base
  default from: "questions@example.com"

  def send_questions(user, group, question)
    email = user.email
    @question = question
    mail(to: email, subject: "#{group.name} - QUESTION: * #{@question} *", host: 'example.com')
  end

  def receive(email)
    logger.info("Got an email about: #{email.subject}")
    if (@user = User.find_by_email(email.from))
      question = email.subject.split('*').last.strip
      if Question.find_by_question(question)
        answer = message.multipart? ? (message.text_part ? message.text_part.body.decoded : nil) : message.body.decoded
      end
    else
      logger.info("No user found with email: #{email.from}")
    end
  end

  def weekly_question(user, group, question)
    email = user.email
    @group_name = Group.find(group.id).name.to_s
    @group_id = group.id
    @question = question.question
    mail(to:email, subject: "#{@group_name} - QUESTION: * #{@question} *", host: 'example.com')
  end

end
