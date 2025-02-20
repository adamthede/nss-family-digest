ruby '3.4.1'
#ruby-gemset=nss-family-digest
source 'https://rubygems.org'

gem 'rails', '8.0.1'
gem 'carrierwave', '~> 3.1.1'
gem 'turbo-rails', '~> 2.0.11'
gem 'devise'
gem 'aws-sdk-s3', '~> 1.141'
gem 'jbuilder'
# Re-add sprockets-rails so asset tasks (and CSS precompilation) work
gem 'sprockets-rails'
gem 'mini_magick'
gem 'pg', '~> 1.5.9'
gem 'simple_form'
# gem 'uglifier' -- Removed for ES6 support via Importmap
gem 'carrierwave-aws', '~> 1.6'
gem 'json', '~> 2.7.1'
gem 'puma', '~> 6.4'
gem 'tailwindcss-rails'
gem 'stimulus-rails'
gem 'importmap-rails'
gem 'ahoy_matey', '~> 5.1.0'
gem 'ahoy_email', '~> 2.1.1'
gem 'geocoder', '~> 1.8.2'
gem 'device_detector', '~> 1.1'
gem "chartkick", "~> 5.0"
gem "groupdate", "~> 6.4"
gem 'sendgrid-ruby'
gem 'email_reply_parser', '~> 0.5.11'
gem "image_processing", "~> 1.13"

group :development do
  gem 'bootsnap', require: false
  gem 'rails_layout'
  gem 'rails-erd'
  gem 'listen'
end

group :development, :test do
  gem 'email_spec'
  gem 'letter_opener'
  gem 'letter_opener_web'
  gem 'rspec-rails'
  gem 'rspec'
  gem 'dotenv-rails'
end

group :test do
  gem 'capybara'
  gem 'fabrication'
  gem 'launchy'
  gem 'shoulda'
  gem 'simplecov', require: false
  gem 'vcr'
  gem 'webmock'
  gem 'shoulda-matchers'
end
