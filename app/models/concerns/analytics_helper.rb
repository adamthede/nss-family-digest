module AnalyticsHelper
  extend ActiveSupport::Concern

  class_methods do
    def top_users(limit: 5)
      joins("LEFT JOIN ahoy_events ON ahoy_events.user_id = users.id")
        .group("users.id, users.email")
        .select(
          "users.email",
          "users.id",
          "COUNT(DISTINCT ahoy_events.id) as event_count",
          "MAX(ahoy_events.time) as last_active"
        )
        .order("event_count DESC")
        .limit(limit)
    end
  end
end