# Preview all emails at http://localhost:3000/rails/mailers/question_mailer
class QuestionMailerPreview < ActionMailer::Preview
  def send_questions
    user = preview_user
    group = Group.first_or_create!(
      name: 'Preview Group',
      description: 'A sample group for preview'
    )
    question = Question.first_or_create!(
      question: "What's your favorite programming language and why?",
      group: group,
      created_at: Time.current
    )

    QuestionMailer.send_questions(user, group, question.question)
  end

  def weekly_digest
    user = preview_user
    group = Group.first_or_create!(
      name: 'Preview Group',
      description: 'A sample group for preview'
    )

    question_record = Question.first_or_create!(
      question: "What's your favorite programming language and why?",
      group: group,
      created_at: Time.current
    )

    # Create some sample answers
    answers = [
      Answer.first_or_create!(
        answer: "Ruby because of its elegant syntax and great community!",
        user: preview_user,
        question: question_record
      ),
      Answer.first_or_create!(
        answer: "Python for its simplicity and versatility.",
        user: another_preview_user,
        question: question_record
      )
    ]

    QuestionMailer.weekly_digest(user, group, question_record, answers, question_record)
  end

  def weekly_question
    user = preview_user
    group = Group.first_or_create!(
      name: 'Preview Group',
      description: 'A sample group for preview'
    )

    question = Question.first_or_create!(
      question: "If you could master any technology instantly, what would it be?",
      group: group,
      created_at: Time.current
    )

    QuestionMailer.weekly_question(user, group, question)
  end

  private

  def preview_user
    User.first_or_create!(
      email: 'preview@example.com',
      password: 'password123456789',
      password_confirmation: 'password123456789'
    )
  end

  def another_preview_user
    User.where(email: 'another_preview@example.com').first_or_create!(
      password: 'password123456789',
      password_confirmation: 'password123456789'
    )
  end
end