# Answers 2 Answers

A Ruby on Rails application that manages and publishes weekly digests of questions and answers for groups. Perfect for families, friends, or colleagues who want to stay connected through meaningful conversations.

## Features

### User Management
- User authentication via Devise
- Profile management with avatar support (Gravatar fallback)
- User groups and memberships

### Group Management
- Create and manage groups
- Add members via email invitations
- Group leader controls and permissions
- Support for multiple group participation

### Question & Answer System
- Pre-populated question database
- Automated weekly question distribution
- Answer submission via web interface
- Digest compilation and distribution
- Sorting and filtering of questions/answers

## Technical Stack

- Ruby 3.4.1
- Rails 8.0.1
- PostgreSQL database
- TailwindCSS for styling
- AWS S3 for file storage
- Postmark for email delivery

## Setup

### Prerequisites

- Ruby 3.4.1
- PostgreSQL
- Node.js and Yarn (for TailwindCSS and JavaScript dependencies)

### Installation

1. Clone the repository and navigate into the project directory.
2. Install Ruby gems:
   ```bash
   bundle install
   ```
3. Install Node.js packages:
   ```bash
   yarn install
   ```
4. Create and migrate the database:
   ```bash
   rails db:create db:migrate
   ```
5. Create a configuration file for environment variables. In `config/application.yml`, set your:
   - AWS credentials
   - Postmark API key
   - Default mailer settings
   - Any other required environment variables

## Local Development

For a smooth local development experience, follow these steps:

1. **Start the development environment:**
   Use the provided binstub which runs the Rails server with TailwindCSS watch enabled:
   ```bash
   bin/dev
   ```
2. **Building CSS assets manually (if needed):**
   If you make changes to your TailwindCSS files and need a manual build, run:
   ```bash
   rails tailwindcss:build
   ```
3. **Managing assets:**
   - To remove previously compiled assets:
     ```bash
     rails assets:clobber
     ```
   - In case you want to precompile assets locally (e.g. to test production settings):
     ```bash
     rails assets:precompile
     ```

## Testing

Run the test suite with:

  ```bash
  bundle exec rspec
  ```



## Deployment

When preparing the application for deployment (Heroku is recommended, but any Rails-supported platform will do):

1. **Precompile Assets:**
   Before deploying, clear out old compiled files and precompile fresh ones:
   ```bash
   rails assets:clobber
   rails tailwindcss:build   # Ensure TailwindCSS is up-to-date
   rails assets:precompile
   ```
2. **Configure Environment Variables:**
   Make sure that your production environment has all required environment variables (AWS credentials, Postmark API key, `SECRET_KEY_BASE`, etc.) either via the server’s configuration or by using a tool like Figaro or the platform’s config vars.

3. **Database Migrations:**
   After deploying your code, run pending migrations:
   ```bash
   rails db:migrate
   ```

4. **Additional Considerations:**
   - Ensure that the `RAILS_SERVE_STATIC_FILES` environment variable is set in production if you plan on serving static assets through Rails.
   - Check your asset host configuration if using a CDN or asset server.

With these steps, your application should start correctly in both development and production environments.

## Additional Commands

For routine maintenance and development updates, you may also use the provided scripts:

- **Setup development environment or update dependencies:**
  ```bash
  bin/setup
  bin/update
  ```

Happy coding!