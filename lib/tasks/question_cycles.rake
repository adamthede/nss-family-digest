namespace :question_cycles do
  desc "Activate scheduled questions (run in the morning)"
  task :activate => :environment do
    # Auto-resume groups whose pause has expired
    Group.where('paused_until <= ?', Date.current).find_each do |group|
      group.resume_now
    end

    # Process scheduled cycles
    QuestionCycle.activate_today.each do |cycle|
      # Only proceed for automatic cycles if group is in automatic mode and not paused
      if cycle.manual || cycle.group.active_for_automatic_cycles?
        cycle.activate!

        # Send emails to active users
        cycle.group.active_users.each do |user|
          QuestionMailer.weekly_question(user, cycle.group, cycle.question).deliver_later
        end
      end
    end
  end

  desc "Close active questions (run in the evening)"
  task :close => :environment do
    # Close cycles that reached end date
    QuestionCycle.close_today.each do |cycle|
      cycle.close!
    end
  end

  desc "Send digests for closed questions"
  task :digest => :environment do
    # Send digests for closed cycles on digest date
    QuestionCycle.digest_today.each do |cycle|
      answers = cycle.question_record.answers

      next if answers.empty?

      cycle.group.active_users.each do |user|
        QuestionMailer.weekly_digest(user, cycle.group, cycle.question, answers, cycle.question_record).deliver_later
      end

      cycle.complete!
    end
  end

  desc "Schedule upcoming automatic cycles"
  task :schedule => :environment do
    Group.where(question_mode: 'automatic')
         .where('paused_until IS NULL OR paused_until <= ?', Date.current)
         .find_each do |group|

      next if group.active_users.empty?

      # Check if we already have a future cycle
      next if group.question_cycles.automatic.where('start_date > ?', Date.current).exists?

      # Schedule next Monday
      next_monday = Date.current.next_occurring(:monday)

      # Select question
      question = Question.select_random_question(group)
      next unless question

      # Create cycle
      group.question_cycles.create!(
        question: question,
        start_date: next_monday,
        end_date: next_monday + 4.days,  # Friday
        digest_date: next_monday + 5.days, # Saturday
        status: :scheduled,
        manual: false
      )
    end
  end

  desc "Run all question cycle tasks in sequence"
  task :all => [:activate, :close, :digest, :schedule]
end