class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_global_admin

  def index
    @stats = {
      # Visit Statistics
      total_visits: Ahoy::Visit.count,
      unique_visitors: Ahoy::Visit.distinct.count(:visitor_token),
      visits_last_30_days: Ahoy::Visit.where('started_at > ?', 30.days.ago).count,

      # Visit Trends
      daily_visits: Ahoy::Visit.group_by_day(:started_at, last: 30).count,
      hourly_visits: Ahoy::Visit.group_by_hour_of_day(:started_at, format: "%l %P").count,

      # Geographic Data
      top_countries: Ahoy::Visit.group(:country).count.sort_by { |_, v| -v }.first(10),
      top_cities: Ahoy::Visit.group(:city).count.sort_by { |_, v| -v }.first(10),

      # Device/Platform Info
      browser_stats: Ahoy::Visit.group(:browser).count,
      device_stats: Ahoy::Visit.group(:device_type).count,

      # Events
      total_events: Ahoy::Event.count,
      recent_events: Ahoy::Event.order(time: :desc).limit(10),
      events_by_name: Ahoy::Event.group(:name).count.sort_by { |_, v| -v }.first(10),

      # Email Campaign Stats
      email_campaigns: Ahoy::Message.group(:campaign).count,
      total_emails_sent: Ahoy::Message.count,
      emails_over_time: Ahoy::Message.group_by_day(:sent_at, last: 30).count
    }
  end

  def daily_visits_data
    render json: Ahoy::Visit.group_by_day(:started_at, last: 30).count
  end

  def hourly_visits_data
    render json: Ahoy::Visit.group_by_hour_of_day(:started_at, format: "%l %P").count
  end

  def countries_data
    render json: Ahoy::Visit.group(:country).count.sort_by { |_, v| -v }.first(10)
  end

  def devices_data
    render json: Ahoy::Visit.group(:device_type).count
  end

  def emails_data
    render json: Ahoy::Message.group_by_day(:sent_at, last: 30).count
  end

  def events_data
    render json: Ahoy::Event.group(:name).count.sort_by { |_, v| -v }.first(10)
  end

  private

  def require_global_admin
    unless current_user&.global_admin?
      redirect_to root_path, alert: "Access denied."
    end
  end
end