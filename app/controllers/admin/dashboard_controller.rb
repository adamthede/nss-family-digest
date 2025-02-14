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
      top_regions: Ahoy::Visit.group(:region).count.sort_by { |_, v| -v }.first(10),
      top_cities: Ahoy::Visit.group(:city).count.sort_by { |_, v| -v }.first(10),

      # Device/Platform Info
      browser_stats: Ahoy::Visit.group(:browser).count,
      device_stats: Ahoy::Visit.group(:device_type).count,

      # Events
      total_events: Ahoy::Event.count,
      recent_events: Ahoy::Event
        .includes(:user)
        .order(time: :desc)
        .limit(10)
        .map { |event|
          {
            name: event.name,
            time: event.time,
            user: event.user&.email || 'Anonymous',
            properties: event.properties
          }
        },
      events_by_name: Ahoy::Event.group(:name).count.sort_by { |_, v| -v }.first(10),

      # Email Campaign Stats
      email_campaigns: Ahoy::Message.group(:campaign).count,
      total_emails_sent: Ahoy::Message.count,
      emails_over_time: Ahoy::Message.group_by_day(:sent_at, last: 30).count,

      # Add User Analytics
      top_users: User
        .joins("LEFT JOIN ahoy_events ON ahoy_events.user_id = users.id")
        .group("users.id, users.email")
        .select(
          "users.email",
          "users.id",
          "COUNT(DISTINCT ahoy_events.id) as event_count",
          "MAX(ahoy_events.time) as last_active"
        )
        .order("event_count DESC")
        .limit(10),

      user_activity_by_day: Ahoy::Event
        .where.not(user_id: nil)
        .group_by_day(:time, last: 30)
        .count,

      most_common_user_actions: Ahoy::Event
        .where.not(user_id: nil)
        .group(:name)
        .order(Arel.sql('COUNT(*) DESC'))
        .limit(5)
        .count
    }
  end

  def daily_visits_data
    render json: Ahoy::Visit.group_by_day(:started_at, last: 30).count
  end

  def hourly_visits_data
    render json: Ahoy::Visit
      .group_by_hour_of_day(
        :started_at,
        format: "%l %P",
        time_zone: Time.zone.name
      )
      .count
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

  def regions_data
    # Format specifically for geo_chart - filter US states and convert to state codes
    visits_by_state = Ahoy::Visit
      .where(country: "United States")
      .group(:region)
      .count

    # Convert state names to two-letter codes for the geo chart
    state_mapping = {
      "Alabama" => "AL", "Alaska" => "AK", "Arizona" => "AZ", "Arkansas" => "AR",
      "California" => "CA", "Colorado" => "CO", "Connecticut" => "CT", "Delaware" => "DE",
      "Florida" => "FL", "Georgia" => "GA", "Hawaii" => "HI", "Idaho" => "ID",
      "Illinois" => "IL", "Indiana" => "IN", "Iowa" => "IA", "Kansas" => "KS",
      "Kentucky" => "KY", "Louisiana" => "LA", "Maine" => "ME", "Maryland" => "MD",
      "Massachusetts" => "MA", "Michigan" => "MI", "Minnesota" => "MN", "Mississippi" => "MS",
      "Missouri" => "MO", "Montana" => "MT", "Nebraska" => "NE", "Nevada" => "NV",
      "New Hampshire" => "NH", "New Jersey" => "NJ", "New Mexico" => "NM", "New York" => "NY",
      "North Carolina" => "NC", "North Dakota" => "ND", "Ohio" => "OH", "Oklahoma" => "OK",
      "Oregon" => "OR", "Pennsylvania" => "PA", "Rhode Island" => "RI", "South Carolina" => "SC",
      "South Dakota" => "SD", "Tennessee" => "TN", "Texas" => "TX", "Utah" => "UT",
      "Vermont" => "VT", "Virginia" => "VA", "Washington" => "WA", "West Virginia" => "WV",
      "Wisconsin" => "WI", "Wyoming" => "WY", "District of Columbia" => "DC"
    }

    formatted_data = visits_by_state.transform_keys { |k| state_mapping[k] || k }
    render json: formatted_data
  end

  def cities_data
    render json: Ahoy::Visit
      .group(:city)
      .count
      .sort_by { |_, v| -v }
      .first(10)
  end

  def user_activity_data
    render json: Ahoy::Event
      .where.not(user_id: nil)
      .group_by_day(:time, last: 30)
      .count
  end

  private

  def require_global_admin
    unless current_user&.global_admin?
      redirect_to root_path, alert: "Access denied."
    end
  end
end