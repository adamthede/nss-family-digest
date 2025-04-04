class QuestionMailer < ApplicationMailer
  # Don't set a default reply_to since we'll generate a unique one for each message
  layout 'mail_layout'

  ##
  # Sends an email containing the specified question to a user.
  #
  # This method builds an email by setting custom application headers with the group, question, and user identifiers.
  # It attempts to locate an existing question record to include its ID in the headers and to generate a secure reply-to address.
  # If no question record is found, it defaults to a preconfigured reply-to address.
  #
  # @param user [User] The recipient of the email.
  # @param group [Group] The group associated with the question, used for header information and the email subject.
  # @param question [Question] The question to be sent.
  # @return [Mail::Message] The configured email message.
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
  # Sends a weekly question email to a user.
  #
  # This method prepares and dispatches an email that includes the group name and question
  # details. It retrieves the corresponding question record for the specified group and question
  # to add relevant application headers and generate a unique Message-ID. The email's reply-to
  # address is conditionally determined: if a question record exists, a secure address is generated;
  # otherwise, a default address from the environment is used.
  #
  # @param user [User] the recipient of the email.
  # @param group [Group] the group associated with the question.
  # @param question [Question] the question to be sent.
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
  # Sends a weekly digest email containing answers for a specified question.
  #
  # This method composes an email digest using details from the provided group, question, answers, and record.
  # It retrieves the user's email, assigns instance variables for the question record, group, question text, and answers,
  # adds application-specific headers with identifiers, and generates a consistent Message-ID for tracking. Finally,
  # it sends the email with a subject line that includes the group name and the question.
  #
  # @param user [User] The recipient of the email (must respond to +email+).
  # @param group [Group] The group context associated with the question.
  # @param question [Question] The question object containing its text and unique identifier.
  # @param answers [Array] The collection of answers for the question.
  # @param record [QuestionRecord] The record that tracks the question within the group.
  #
  # @return [Mail::Message] The constructed email message.
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
