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
- Multiple group participation support

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

1. **Prerequisites**
   - Ruby 3.4.1
   - PostgreSQL
   - Node.js & Yarn (for TailwindCSS)

2. **Installation**
   ```bash
   bundle install
   rails db:create db:migrate
   ```

3. **Environment Variables**
   Create `config/application.yml` with:
   - AWS credentials
   - Postmark API key
   - Default mailer settings

4. **Development**
   ```bash
   bin/dev    # Runs Rails server with TailwindCSS watching
   ```

## Testing

  ```bash
  bundle exec rspec
  ```


## Deployment

The application is designed for deployment on any platform supporting Ruby on Rails (Heroku recommended).