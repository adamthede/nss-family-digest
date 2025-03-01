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
        weekly_visits: Ahoy::Visit.group_by_week(:started_at, last: 12).count,
        monthly_visits: Ahoy::Visit.group_by_month(:started_at, last: 12).count,
        hourly_visits: Ahoy::Visit.group_by_hour_of_day(:started_at, format: "%l %P").count,
        day_of_week_visits: Ahoy::Visit.group_by_day_of_week(:started_at, format: "%A").count,
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
        emails_over_time: Ahoy::Message.group_by_day(:sent_at, last: 30).count,
        emails_by_week: Ahoy::Message.group_by_week(:sent_at, last: 12).count,
        emails_by_month: Ahoy::Message.group_by_month(:sent_at, last: 12).count,
        emails_by_hour: Ahoy::Message.group_by_hour_of_day(:sent_at, format: "%l %P").count,
        emails_by_day_of_week: Ahoy::Message.group_by_day_of_week(:sent_at, format: "%A").count
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
        events_by_name: Ahoy::Event.group(:name).count.sort_by { |_, v| -v }.first(10),
        events_by_day: Ahoy::Event.group_by_day(:time, last: 30).count,
        events_by_week: Ahoy::Event.group_by_week(:time, last: 12).count,
        events_by_hour: Ahoy::Event.group_by_hour_of_day(:time, format: "%l %P").count,
        events_by_day_of_week: Ahoy::Event.group_by_day_of_week(:time, format: "%A").count
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

  def self.group_analytics
    Rails.cache.fetch("group_analytics", expires_in: 15.minutes) do
      {
        total_groups: Group.count,
        active_groups: Group.where('last_activity_at >= ?', 30.days.ago).count,
        groups_by_creation_date: Group.group_by_month(:created_at, last: 12).count,
        groups_by_week: Group.group_by_week(:created_at, last: 8).count,
        groups_by_size: group_size_distribution,
        avg_members_per_group: Group.joins(:memberships).group('groups.id').count.values.sum.to_f / [Group.count, 1].max
      }
    end
  end

  def self.group_size_distribution
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
end