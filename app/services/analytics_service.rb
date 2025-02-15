class AnalyticsService
  def self.recent_events(limit: 5)
    Rails.cache.fetch("recent_events_#{limit}", expires_in: 5.minutes) do
      Ahoy::Event
        .includes(:user)
        .order(time: :desc)
        .limit(limit)
        .map { |event|
          {
            name: event.name,
            time: event.time,
            user: event.user&.email || 'Anonymous',
            properties: event.properties
          }
        }
    end
  end

  def self.most_common_user_actions(limit: 5)
    Rails.cache.fetch("common_user_actions_#{limit}", expires_in: 15.minutes) do
      Ahoy::Event
        .where.not(user_id: nil)
        .group(:name)
        .order(Arel.sql('COUNT(*) DESC'))
        .limit(limit)
        .count
    end
  end

  def self.visit_statistics
    Rails.cache.fetch("visit_statistics", expires_in: 15.minutes) do
      {
        total_visits: Ahoy::Visit.count,
        unique_visitors: Ahoy::Visit.distinct.count(:visitor_token),
        visits_last_30_days: Ahoy::Visit.where('started_at > ?', 30.days.ago).count
      }
    end
  end

  def self.visit_details
    Rails.cache.fetch("visit_details", expires_in: 15.minutes) do
      {
        total_visits: Ahoy::Visit.count,
        unique_visitors: Ahoy::Visit.distinct.count(:visitor_token),
        visits_last_30_days: Ahoy::Visit.where('started_at > ?', 30.days.ago).count,
        daily_visits: Ahoy::Visit.group_by_day(:started_at, last: 30).count,
        hourly_visits: Ahoy::Visit.group_by_hour_of_day(:started_at, format: "%l %P").count,
        top_countries: Ahoy::Visit.group(:country).count.sort_by { |_, v| -v }.first(10),
        top_regions: Ahoy::Visit.group(:region).count.sort_by { |_, v| -v }.first(10),
        top_cities: Ahoy::Visit.group(:city).count.sort_by { |_, v| -v }.first(10),
        browser_stats: Ahoy::Visit.group(:browser).count,
        device_stats: Ahoy::Visit.group(:device_type).count
      }
    end
  end

  def self.email_statistics
    Rails.cache.fetch("email_statistics", expires_in: 15.minutes) do
      {
        email_campaigns: Ahoy::Message.group(:campaign).count,
        total_emails_sent: Ahoy::Message.count,
        emails_over_time: Ahoy::Message.group_by_day(:sent_at, last: 30).count
      }
    end
  end

  def self.event_statistics
    Rails.cache.fetch("event_statistics", expires_in: 5.minutes) do
      {
        total_events: Ahoy::Event.count,
        recent_events: Ahoy::Event
          .includes(:user)
          .order(time: :desc)
          .limit(20)
          .map { |event|
            {
              name: event.name,
              time: event.time,
              user: event.user&.email || 'Anonymous',
              properties: event.properties
            }
          },
        events_by_name: Ahoy::Event.group(:name).count.sort_by { |_, v| -v }.first(10)
      }
    end
  end

  def self.user_statistics(user_id)
    Rails.cache.fetch("user_statistics_#{user_id}", expires_in: 5.minutes) do
      {
        total_visits: Ahoy::Visit.where(user_id: user_id).count,
        total_events: Ahoy::Event.where(user_id: user_id).count,
        most_common_events: Ahoy::Event
          .where(user_id: user_id)
          .group(:name)
          .order('count_id DESC')
          .count(:id)
          .first(5),
        activity_by_day: Ahoy::Event
          .where(user_id: user_id)
          .group_by_day(:time, last: 30)
          .count,
        browser_stats: Ahoy::Visit
          .where(user_id: user_id)
          .group(:browser)
          .count,
        device_stats: Ahoy::Visit
          .where(user_id: user_id)
          .group(:device_type)
          .count
      }
    end
  end

  def self.users_dashboard_statistics
    Rails.cache.fetch("users_dashboard_stats", expires_in: 5.minutes) do
      {
        top_users: User.top_users(limit: 20),
        user_activity_by_day: Ahoy::Event
          .where.not(user_id: nil)
          .group_by_day(:time, last: 30)
          .count,
        most_common_user_actions: most_common_user_actions(limit: 10)
      }
    end
  end
end