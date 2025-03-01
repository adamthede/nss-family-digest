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
      most_common_user_actions: AnalyticsService.most_common_user_actions,
      signups_this_week: User.where('created_at >= ?', 7.days.ago).count,
      active_users_today: Ahoy::Event.where('time >= ?', 24.hours.ago).distinct.count(:user_id),
      page_views_per_visit: calculate_page_views_per_visit,
      top_browser: top_browser,
      top_device_type: top_device_type,
      events_per_day: events_per_day,
      new_visitors_percentage: new_visitors_percentage,
      most_active_hour: most_active_hour
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
    @stats = AnalyticsService.users_dashboard_statistics.merge({
      recent_signups: User.order(created_at: :desc).limit(10).map do |user|
        {
          id: user.id,
          email: user.email,
          name: user.respond_to?(:name) ? user.name : nil,
          created_at: user.created_at
        }
      end,
      signups_today: User.where('created_at >= ?', 24.hours.ago).count,
      signups_this_week: User.where('created_at >= ?', 7.days.ago).count
    })
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

  def recent_signups
    @recent_signups = User.order(created_at: :desc).paginate(page: params[:page], per_page: 20)
  end

  def groups
    @stats = {
      total_groups: Group.count,
      active_groups: Group.where('last_activity_at >= ?', 30.days.ago).count,
      avg_members_per_group: Group.joins(:memberships).group('groups.id').count.values.sum.to_f / [Group.count, 1].max,
      groups_created_this_month: Group.where('created_at >= ?', 30.days.ago).count,
      groups_by_size: group_size_distribution,
      recent_groups: Group.order(created_at: :desc).limit(10),
    }

    # For the groups table without pagination
    @groups = Group.includes(:memberships)
                  .order(created_at: :desc)
                  .limit(50)

    # Calculate email counts for each group
    @group_email_counts = {}
    @groups.each do |group|
      user_ids = group.users.pluck(:id)
      @group_email_counts[group.id] = Ahoy::Message.where(user_id: user_ids).count
    end
  end

  def group_details
    @group = Group.find(params[:id])
    @members = @group.memberships.includes(:user).select { |m| m.user.present? }

    # Get email statistics for this group
    @email_stats = calculate_group_email_stats(@group)

    # Check if GroupActivity exists before trying to use it
    if defined?(GroupActivity)
      @activity = GroupActivity.where(group_id: @group.id).order(created_at: :desc).limit(50)
    else
      @activity = []
    end

    @stats = {
      member_count: @members.count,
      active_members: @members.respond_to?(:where) && @members.first.respond_to?(:last_active_at) ?
                      @members.where('last_active_at >= ?', 30.days.ago).count : 0,
      created_at: @group.created_at,
      leader: @group.leader,
      total_emails_sent: @email_stats[:total_emails],
      emails_last_30_days: @email_stats[:last_30_days],
      email_open_rate: @email_stats[:open_rate]
    }
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

  def calculate_page_views_per_visit
    total_events = Ahoy::Event.count
    total_visits = Ahoy::Visit.count

    if total_visits > 0
      avg = (total_events.to_f / total_visits).round(1)
      avg.to_s
    else
      "0"
    end
  end

  def top_browser
    Ahoy::Visit.group(:browser).order('count_id DESC').count(:id).first&.first || 'Unknown'
  end

  def top_device_type
    Ahoy::Visit.group(:device_type).order('count_id DESC').count(:id).first&.first || 'Unknown'
  end

  def events_per_day
    events_count = Ahoy::Event.where('time >= ?', 7.days.ago).count
    days = 7
    avg = (events_count.to_f / days).round
    avg.to_s
  end

  def new_visitors_percentage
    total_visits = Ahoy::Visit.count
    return "0%" if total_visits == 0

    new_visits = Ahoy::Visit.select(:visitor_token).distinct.count
    percentage = ((new_visits.to_f / total_visits) * 100).round
    "#{percentage}%"
  end

  def most_active_hour
    # Alternative approach using raw SQL
    sql = "SELECT EXTRACT(HOUR FROM time) AS hour_of_day, COUNT(*) AS event_count
           FROM ahoy_events
           GROUP BY hour_of_day
           ORDER BY event_count DESC
           LIMIT 1"

    result = ActiveRecord::Base.connection.execute(sql).first

    if result && result["hour_of_day"]
      hour = result["hour_of_day"].to_i
      meridian = hour >= 12 ? "PM" : "AM"
      display_hour = hour % 12
      display_hour = 12 if display_hour == 0
      "#{display_hour} #{meridian}"
    else
      "N/A"
    end
  end

  def group_size_distribution
    # Returns distribution of groups by member count
    counts = Group.joins(:memberships)
                 .group('groups.id')
                 .count

    distribution = {
      '1-5 members': 0,
      '6-10 members': 0,
      '11-20 members': 0,
      '21-50 members': 0,
      '51+ members': 0
    }

    counts.each do |_, count|
      case count
      when 1..5
        distribution[:'1-5 members'] += 1
      when 6..10
        distribution[:'6-10 members'] += 1
      when 11..20
        distribution[:'11-20 members'] += 1
      when 21..50
        distribution[:'21-50 members'] += 1
      else
        distribution[:'51+ members'] += 1
      end
    end

    distribution
  end

  def calculate_group_email_stats(group)
    # Get all user IDs in this group
    user_ids = group.users.pluck(:id)

    # Query Ahoy::Message for emails sent to these users
    emails = Ahoy::Message.where(user_id: user_ids)

    # Calculate statistics
    total_emails = emails.count
    last_30_days = emails.where('sent_at >= ?', 30.days.ago).count

    # Return a hash of statistics
    {
      total_emails: total_emails,
      last_30_days: last_30_days
    }
  end
end