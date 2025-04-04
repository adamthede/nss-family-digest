class QuestionMailer < ApplicationMailer
  # Don't set a default reply_to since we'll generate a unique one for each message
  layout 'mail_layout'

  ##
  # Sends an email containing a question to a specified user.
  #
  # This method composes and dispatches an email within a group context. It sets custom headers including the group,
  # question, and user identifiers, generates a unique Message-ID, and determines a secure reply-to address based on the
  # presence of a corresponding question record.
  #
  # @param user [User] The email recipient.
  # @param group [Group] The group associated with the question, providing context for the header and subject.
  # @param question [Question] The question content to be sent in the email.
  #
  # @return [Mail::Message] The constructed mail message.
  #
  # @example
  #   send_questions(user, group, question)
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

  ##
  # Sends a weekly question email containing a group question to a user.
  #
  # Retrieves the group’s name and the question content from the provided objects, locates an associated question record if one exists,
  # and sets application-specific email headers including a consistent Message-ID. The method then determines a secure reply-to address
  # based on the presence of a question record and sends an email with a subject that incorporates the group name and question.
  #
  # @param user [User] The recipient of the email, expected to have an accessible email attribute.
  # @param group [Group] The group context for the email; its ID and name are used for headers and email subject formatting.
  # @param question [Question] The question object containing the question text and identifier.
  #
  # @note The reply-to address is set by generating a secure address if a question record is found; otherwise, it falls back to the value of ENV['SENDGRID_INBOUND'].
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

  ##
  # Sends a weekly digest email containing the answers for a specific question.
  #
  # Composes and sends an email that includes the group name, question text, and associated answers.
  # The method sets custom email headers using the group, question, question record, and user identifiers,
  # and generates a consistent Message-ID to track the email.
  #
  # @param user [User] The recipient user of the digest email.
  # @param group [Group] The group associated with the question.
  # @param question [Question] The question object, providing the question text and identifier.
  # @param answers [Array] A collection of answers related to the question.
  # @param record [QuestionRecord] The record used to configure mail headers.
  #
  # @example
  #   weekly_digest(user, group, question, answers, record)
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
