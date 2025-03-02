namespace :digests do
  desc "Generate weekly digests for all groups"
  task generate_weekly: :environment do
    puts "Generating weekly digests for all groups..."

    # Get all active groups
    active_groups = Group.joins(:memberships).where(memberships: { status: 'active' }).distinct

    # Set date range for the past week
    end_date = Date.today
    start_date = end_date - 7.days

    success_count = 0
    failure_count = 0

    active_groups.each do |group|
      puts "Processing group: #{group.name} (ID: #{group.id})"

      # Check if there are any question records in this period
      question_count = QuestionRecord.where(group: group)
                                    .in_period(start_date, end_date)
                                    .count

      if question_count == 0
        puts "  No questions found for this period, skipping..."
        next
      end

      # Generate digest
      service = DigestGeneratorService.new(group, start_date, end_date)

      if service.generate
        digest = service.instance_variable_get(:@digest)
        puts "  Digest created successfully (ID: #{digest.id})"
        success_count += 1
      else
        puts "  Failed to create digest: #{service.errors.join(', ')}"
        failure_count += 1
      end
    end

    puts "Weekly digest generation completed."
    puts "Results: #{success_count} digests created, #{failure_count} failures."
  end

  desc "Send all pending digests"
  task send_pending: :environment do
    puts "Sending pending digests..."

    pending_digests = QuestionDigest.where(status: [:pending, :processing])

    success_count = 0
    failure_count = 0

    pending_digests.each do |digest|
      puts "Processing digest ID: #{digest.id} for group: #{digest.group.name}"

      service = DigestDeliveryService.new(digest)

      if service.deliver
        puts "  Emails queued successfully"
        digest.update(status: :sent)
        success_count += 1
      else
        puts "  Failed to send emails: #{service.errors.join(', ')}"
        digest.update(status: :failed)
        failure_count += 1
      end
    end

    puts "Pending digest delivery completed."
    puts "Results: #{success_count} digests sent, #{failure_count} failures."
  end

  desc "Generate and send weekly digests for all groups"
  task weekly: :environment do
    Rake::Task["digests:generate_weekly"].invoke
    Rake::Task["digests:send_pending"].invoke
  end
end