class Ahoy::Store < Ahoy::DatabaseStore
  # Track all visits including bots
  def track_visit(data)
    super(data)
  end
end

# Set to true for JavaScript tracking
Ahoy.api = true

# Better user tracking
Ahoy.server_side_visits = true

# Track visits reliably
Ahoy.cookie_domain = :all

# Associate users
Ahoy.user_method = :current_user

# Set visit duration
Ahoy.visit_duration = 30.minutes

# Enable geocoding
Ahoy.geocode = true

# Configure which URLs to mask
Ahoy.mask_ips = true