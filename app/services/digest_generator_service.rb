class DigestGeneratorService
  attr_reader :group, :start_date, :end_date, :errors

  def initialize(group, start_date, end_date)
    @group = group
    @start_date = start_date.to_date
    @end_date = end_date.to_date
    @errors = []
  end

  def generate
    return false unless valid?

    ActiveRecord::Base.transaction do
      create_digest
      associate_question_records
      @digest.update(status: :sent)
      true
    rescue => e
      @errors << "Error generating digest: #{e.message}"
      @digest&.update(status: :failed)
      Rails.logger.error("Digest generation failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    end
  end

  private

  def valid?
    if @start_date > @end_date
      @errors << "Start date must be before end date"
      return false
    end

    if @group.nil?
      @errors << "Group must be specified"
      return false
    end

    true
  end

  def create_digest
    @digest = QuestionDigest.create!(
      group: @group,
      start_date: @start_date,
      end_date: @end_date,
      status: :processing
    )
  end

  def associate_question_records
    records = QuestionRecord.where(group: @group)
                           .in_period(@start_date, @end_date)
                           .without_digest

    if records.empty?
      @errors << "No questions found for the specified period"
      raise "No questions found for the specified period"
    end

    records.update_all(question_digest_id: @digest.id)
  end
end