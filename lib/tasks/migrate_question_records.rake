# lib/tasks/migrate_question_records.rake
namespace :migrate do
  desc "Create question cycles for existing question records"
  task :question_records_to_cycles => :environment do
    # Find QuestionRecords that don't have associated QuestionCycles
    records_without_cycles = QuestionRecord.where.not(id: QuestionCycle.pluck(:question_record_id))

    puts "Found #{records_without_cycles.count} question records without cycles"

    # Track statistics
    created_count = 0
    skipped_count = 0

    records_without_cycles.find_each do |record|
      # Check for nil associations
      if record.group.nil?
        puts "SKIPPING: Question record ##{record.id} has no associated group"
        skipped_count += 1
        next
      end

      if record.question.nil?
        puts "SKIPPING: Question record ##{record.id} has no associated question"
        skipped_count += 1
        next
      end

      # Determine approximate dates based on created_at
      start_date = record.created_at.to_date
      end_date = start_date + 4.days
      digest_date = start_date + 5.days

      # Determine status based on dates
      status = if Date.current < start_date
                 :scheduled
               elsif Date.current.between?(start_date, end_date)
                 :active
               elsif Date.current.between?(end_date + 1.day, digest_date)
                 :closed
               else
                 :completed
               end

      # Create the cycle
      begin
        cycle = record.group.question_cycles.create!(
          question: record.question,
          question_record: record,
          start_date: start_date,
          end_date: end_date,
          digest_date: digest_date,
          status: status,
          manual: false
        )

        puts "Created cycle for question record ##{record.id}: #{cycle.status}"
        created_count += 1
      rescue => e
        puts "ERROR: Failed to create cycle for question record ##{record.id}: #{e.message}"
        skipped_count += 1
      end
    end

    puts "Migration complete! Created #{created_count} cycles, skipped #{skipped_count} records"
  end

  desc "Cleanup orphaned question records (optional)"
  task :cleanup_orphaned_records => :environment do
    # Find orphaned records
    orphaned_records = QuestionRecord.where(group_id: nil).or(QuestionRecord.where(question_id: nil))

    if orphaned_records.any?
      puts "Found #{orphaned_records.count} orphaned question records"

      if ENV['DESTROY'] == 'true'
        orphaned_records.destroy_all
        puts "Destroyed all orphaned records"
      else
        puts "To delete these records, run: rake migrate:cleanup_orphaned_records DESTROY=true"
      end
    else
      puts "No orphaned question records found"
    end
  end
end