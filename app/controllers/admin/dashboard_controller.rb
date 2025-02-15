class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_global_admin
  before_action :set_common_stats

  def index
    @stats = {
      **AnalyticsService.visit_statistics,
      total_users: User.count,
      total_events: Ahoy::Event.count,
      total_emails_sent: Ahoy::Message.count,
      email_campaigns: Rails.cache.fetch("email_campaigns", expires_in: 30.minutes) do
        Ahoy::Message.group(:campaign).count
      end,
      recent_events: AnalyticsService.recent_events,
      top_users: User.top_users,
      most_common_user_actions: AnalyticsService.most_common_user_actions
    }
  end

  def visits
    @stats = AnalyticsService.visit_details
  end

  def emails
    @stats = AnalyticsService.email_statistics
  end

  def events
    @stats = AnalyticsService.event_statistics
  end

  def users
    @stats = AnalyticsService.users_dashboard_statistics
  end

  def daily_visits_data
    render json: AnalyticsService.visit_details[:daily_visits]
  end

  def hourly_visits_data
    render json: AnalyticsService.visit_details[:hourly_visits]
  end

  def countries_data
    render json: AnalyticsService.visit_details[:top_countries]
  end

  def devices_data
    render json: AnalyticsService.visit_details[:device_stats]
  end

  def emails_data
    render json: AnalyticsService.email_statistics[:emails_over_time]
  end

  def events_data
    render json: AnalyticsService.event_statistics[:events_by_name]
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

  def user_details
    @user = User.find(params[:id])
    @visits = Ahoy::Visit.where(user_id: @user.id)
                        .includes(events: :user)
                        .order(started_at: :desc)
    @stats = AnalyticsService.user_statistics(@user.id)
  end

  private

  def set_common_stats
    @total_users = User.count
    @total_visits = Ahoy::Visit.count
    @total_events = Ahoy::Event.count
    @total_emails_sent = Ahoy::Message.count
  end

  def require_global_admin
    unless current_user&.global_admin?
      redirect_to root_path, alert: "Access denied."
    end
  end
end