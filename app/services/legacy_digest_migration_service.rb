class LegacyDigestMigrationService
  attr_reader :group, :errors

  def initialize(group)
    @group = group
    @errors = []
  end

  def migrate
    return false if group.nil?

    ActiveRecord::Base.transaction do
      # Get all legacy question records that aren't part of a digest
      legacy_records = group.question_records.where(question_digest_id: nil).order(created_at: :asc)

      # Group records by week (Sunday to Saturday)
      records_by_week = group_by_week(legacy_records)

      # Create digests for each week
      records_by_week.each do |week_range, records|
        # Skip if no records for this week
        next if records.empty?

        # Create a new digest for this week
        digest = group.question_digests.create!(
          start_date: week_range.first,
          end_date: week_range.last,
          status: 'sent',
          sent_at: records.last.created_at
        )

        # Associate records with the new digest
        records.each do |record|
          record.update!(question_digest_id: digest.id)
        end
      end

      return true
    end
  rescue => e
    @errors << "Migration failed: #{e.message}"
    return false
  end

  private

  def group_by_week(records)
    records_by_week = {}

    records.each do |record|
      # Find the start of the week (Sunday)
      week_start = record.created_at.beginning_of_week(:sunday)
      week_end = week_start.end_of_week(:sunday)
      week_range = (week_start.to_date..week_end.to_date)

      # Initialize the array for this week if it doesn't exist
      records_by_week[week_range] ||= []

      # Add the record to this week's array
      records_by_week[week_range] << record
    end

    records_by_week
  end
end