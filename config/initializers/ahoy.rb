class Ahoy::Store < Ahoy::DatabaseStore
  def track_visit(data)
    # Track all visits including bots
    super(data)
  end
end

# Set to true for JavaScript tracking
Ahoy.api = false

# Better user tracking
Ahoy.server_side_visits = true

# Track visits reliably
Ahoy.cookie_domain = :all

# Associate users
Ahoy.user_method = :current_user

# Automatic controller tracking
Ahoy.track_actions = true

# Set visit duration
Ahoy.visit_duration = 30.minutes