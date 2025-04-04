class QuestionMailer < ApplicationMailer
  # Don't set a default reply_to since we'll generate a unique one for each message
  layout 'mail_layout'

  ##
  # Sends an email with a specific question to a user within a group context.
  #
  # This method retrieves the user's email and the group's ID, then attempts to locate an existing
  # question record for additional context. It adds application-specific headers including group,
  # question, question record, and user identifiers. A consistent Message-ID is generated and a
  # secure reply-to address is determined based on whether the question record exists. Finally,
  # an email is composed with a subject that incorporates the group's name and the question text.
  #
  # @param user [User] the recipient of the email.
  # @param group [Group] the group context associated with the question.
  # @param question [Question] the question to be sent.
  # @return [Mail::Message] the generated email message ready for delivery.
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
  # Sends a weekly question email to a user with custom headers.
  #
  # This method composes and sends a weekly question email. It retrieves the group's name,
  # extracts the question text for the email subject, and attempts to locate an associated question record.
  # Application-specific headers are added—including group, question, question record (if available), and user identifiers.
  # A consistent Message-ID is generated, and the reply-to address is set dynamically based on the presence
  # of a question record.
  #
  # @param user [User] The recipient of the email.
  # @param group [Group] The group used to retrieve the name and identifier for email composition.
  # @param question [Question] The question object providing the text and identifier for the email.
  #
  # @example
  #   weekly_question(user, group, question)
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
  # Sends a weekly digest email containing a question and its associated answers.
  #
  # Prepares and dispatches an email to a user with a weekly digest. The email includes the question text,
  # its answers, and contextual information from the corresponding group. Application-specific headers,
  # including identifiers for the group, question, question record, and user, are added to facilitate
  # tracking. A consistent Message-ID is generated to uniquely identify the email.
  #
  # @param user [User] The recipient user for the digest.
  # @param group [Group] The group context associated with the question.
  # @param question [Question] The question, from which the question text and identifier are derived.
  # @param answers [Array<Answer>] A collection of answers corresponding to the question.
  # @param record [QuestionRecord] The record used for tracking additional metadata about the question.
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
