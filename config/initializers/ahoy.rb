class Ahoy::Store < Ahoy::DatabaseStore
  ##
  # Tracks a visit, including those from bots.
  #
  # This method delegates visit tracking to the superclass. The provided visit data is passed along to ensure
  # that all visits, bot visits included, are recorded.
  #
  # @param data [Hash] Information related to the visit event.
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