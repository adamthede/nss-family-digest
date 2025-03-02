class DigestDeliveryService
  attr_reader :digest, :errors

  def initialize(digest)
    @digest = digest
    @errors = []
  end

  def deliver
    return false unless valid?

    begin
      send_emails_to_active_members
      true
    rescue => e
      @errors << "Error sending digest emails: #{e.message}"
      Rails.logger.error("Digest email delivery failed: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      false
    end
  end

  private

  def valid?
    if @digest.nil?
      @errors << "Digest must be specified"
      return false
    end

    if @digest.question_records.empty?
      @errors << "Digest has no questions to send"
      return false
    end

    true
  end

  def send_emails_to_active_members
    active_members = @digest.group.active_users

    if active_members.empty?
      @errors << "No active members found in the group"
      return false
    end

    active_members.each do |member|
      DigestMailer.weekly_digest(member, @digest).deliver_later
    end
  end
end