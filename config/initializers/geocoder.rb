Geocoder.configure(
  # Geocoding options
  timeout: 3,                      # geocoding service timeout (secs)
  lookup: :ipapi_com,             # name of geocoding service (symbol)
  ip_lookup: :ipapi_com,          # name of IP address geocoding service
  language: :en,                  # ISO-639 language code
  use_https: true,                # use HTTPS for lookup requests? (if supported)

  # Calculation options
  units: :mi,                     # :km for kilometers or :mi for miles
  distances: :linear              # :spherical or :linear
)