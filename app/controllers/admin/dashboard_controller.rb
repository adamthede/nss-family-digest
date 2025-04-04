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
    @stats = AnalyticsService.group_analytics.merge({
      recent_groups: Group.order(created_at: :desc).limit(10)
    })

    # For the groups table without pagination
    @groups = Group.includes(:memberships)
                  .order(created_at: :desc)
                  .limit(50)
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
      emails_last_30_days: @email_stats[:last_30_days]
    }
  end

  ##
  # Renders JSON data representing group activity trends for the last 30 days.
  #
  # This method checks whether the GroupActivity model is defined. If it is, the method groups
  # GroupActivity records by their creation date; otherwise, it falls back to grouping Membership
  # records as a proxy for group activity. The resulting data is rendered as a JSON response
  # where keys represent dates and values represent the count of activities for that day.
  def group_activity_data
    # Check if GroupActivity exists before trying to use it
    if defined?(GroupActivity)
      render json: GroupActivity.group_by_day(:created_at, last: 30).count
    else
      # Fallback to memberships as a proxy for group activity
      render json: Membership.group_by_day(:created_at, last: 30).count
    end
  end

  ##
  # Computes and renders statistics for email reply events.
  #
  # Determines the analysis time period based on the "period" request parameter (defaulting
  # to "week" if not provided), retrieves email reply events from Ahoy::Event occurring
  # after the computed start date, and calculates several metrics:
  #
  # - Identification methods count for events with name "email_reply.answer_created"
  # - Aggregated event counts by event type (with the "email_reply." prefix removed)
  # - Success rate as the percentage of successful replies over all email reply events
  #
  # The action responds with an HTML view by default and with a JSON payload containing
  # the computed statistics if requested.
  #
  # @return [void] Renders HTML or JSON with email reply statistics.
  def email_reply_stats
    @time_period = params[:period] || 'week'

    case @time_period
    when 'day'
      @start_date = 1.day.ago
    when 'week'
      @start_date = 1.week.ago
    when 'month'
      @start_date = 1.month.ago
    else
      @start_date = 1.month.ago
    end

    # Get all email reply events
    @email_events = Ahoy::Event
      .where("name LIKE 'email_reply.%'")
      .where('time > ?', @start_date)

    # Get counts for different reply identification methods
    @identification_methods = @email_events
      .where(name: 'email_reply.answer_created')
      .group("properties ->> 'identification_method'")
      .count

    # Get counts by event type
    @event_counts = @email_events
      .group('name')
      .count
      .transform_keys { |k| k.gsub('email_reply.', '') }

    # Get success rate
    @successful_replies = @email_events
      .where(name: 'email_reply.answer_created')
      .count

    @all_replies = @email_events.count
    @success_rate = @all_replies > 0 ? (@successful_replies.to_f / @all_replies * 100).round(2) : 0

    # Return JSON if requested
    respond_to do |format|
      format.html # Render HTML view
      format.json do
        render json: {
          identification_methods: @identification_methods,
          event_counts: @event_counts,
          success_rate: @success_rate,
          time_period: @time_period
        }
      end
    end
  end

  private

  ##
  # Sets instance variables with aggregate statistics for the admin dashboard.
  #
  # Retrieves and assigns the total count of users, visits, events, and emails sent from the
  # corresponding models (User, Ahoy::Visit, Ahoy::Event, Ahoy::Message) to instance variables.
  # These statistics are used to power various analytics displays on the dashboard.
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
    # Replace raw SQL with Groupdate
    result = Ahoy::Event.group_by_hour_of_day(:time).count.max_by { |_, count| count }

    if result
      hour = result[0].to_i
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

    # Add group creation trends using Groupdate
    distribution[:creation_by_month] = Group.group_by_month(:created_at, last: 12).count
    distribution[:creation_by_week] = Group.group_by_week(:created_at, last: 8).count

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

    # Add email trends using Groupdate
    email_trends = {
      by_day: emails.group_by_day(:sent_at, last: 14).count,
      by_week: emails.group_by_week(:sent_at, last: 8).count,
      by_hour: emails.group_by_hour_of_day(:sent_at, format: "%l %P").count
    }

    # Return a hash of statistics
    {
      total_emails: total_emails,
      last_30_days: last_30_days,
      trends: email_trends
    }
  end
end