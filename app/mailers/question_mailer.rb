class QuestionMailer < ApplicationMailer
  # Don't set a default reply_to since we'll generate a unique one for each message
  layout 'mail_layout'

  def send_questions(user, group, question)
    email = user.email
    @question = question
    @group_id = group.id

    # Find question record if it exists
    question_record = QuestionRecord.find_by(group: group, question: question)

    # Add headers using the helper
    add_app_headers(
      group_id: group.id,
      question_id: question.id,
      question_record_id: question_record&.id,
      user_id: user.id
    )

    # Generate a consistent message ID
    headers['Message-ID'] = generate_message_id('question', {
      question: question.id,
      group: group.id,
      user: user.id
    })

    # Generate secure reply-to address if we have a question record
    reply_to = question_record ? secure_reply_to(question_record.id) : ENV['SENDGRID_INBOUND']

    mail(
      to: email,
      subject: "#{group.name} - QUESTION: * #{@question} *",
      reply_to: reply_to
    )
  end

  def weekly_question(user, group, question)
    email = user.email
    @group_name = Group.find(group.id).name.to_s
    @group_id = group.id
    @question = question.question

    # Find or get question record
    question_record = QuestionRecord.find_by(group_id: group.id, question_id: question.id)

    # Add headers using the helper
    add_app_headers(
      group_id: group.id,
      question_id: question.id,
      question_record_id: question_record&.id,
      user_id: user.id
    )

    # Generate a consistent message ID
    headers['Message-ID'] = generate_message_id('weekly-question', {
      question: question.id,
      group: group.id,
      user: user.id
    })

    # Generate secure reply-to address if we have a question record
    reply_to = question_record ? secure_reply_to(question_record.id) : ENV['SENDGRID_INBOUND']

    mail(
      to: email,
      subject: "#{@group_name} - QUESTION: * #{@question} *",
      reply_to: reply_to
    )
  end

  def weekly_digest(user, group, question, answers, record)
    email = user.email
    @question_record = record
    @group = Group.find(group.id)
    @question = question.question
    @answers = answers

    # Add headers using the helper
    add_app_headers(
      group_id: group.id,
      question_id: question.id,
      question_record_id: record.id,
      user_id: user.id
    )

    # Generate a consistent message ID
    headers['Message-ID'] = generate_message_id('weekly-digest', {
      question: question.id,
      group: group.id,
      user: user.id,
      record: record.id
    })

    mail(to: email, subject: "#{@group.name} - ANSWERS FOR: #{@question}")
  end

end
