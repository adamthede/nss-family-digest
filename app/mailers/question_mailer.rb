class QuestionMailer < ApplicationMailer
  default reply_to: ENV['POSTMARK_INBOUND']
  layout 'mail_layout'

  def send_questions(user, group, question)
    email = user.email
    @question = question
    @group_id = group.id
    mail(to: email, subject: "#{group.name} - QUESTION: * #{@question} *")
  end

  def weekly_question(user, group, question)
    email = user.email
    @group_name = Group.find(group.id).name.to_s
    @group_id = group.id
    @question = question.question
    mail(to: email, subject: "#{@group_name} - QUESTION: * #{@question} *")
  end

  def weekly_digest(user, group, question, answers, record)
    email = user.email
    @question_record = record
    @group = Group.find(group.id)
    @question = question.question
    @answers = answers
    mail(to: email, subject: "#{@group.name} - ANSWERS FOR: #{@question}")
  end

end
