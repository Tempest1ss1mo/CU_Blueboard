# Moderation configuration
# Configure moderator email whitelist via environment variable

Rails.application.config.moderator_emails =
  ENV.fetch('MODERATOR_EMAILS', '')
     .split(',')
     .map(&:strip)
     .reject(&:empty?)

Rails.logger.info "Moderator whitelist configured with #{Rails.application.config.moderator_emails.size} email(s)"

# Configure allowed login emails whitelist (bypass domain restriction)
# For TA/graders testing with personal emails (gmail, etc.)
Rails.application.config.allowed_login_emails =
  ENV.fetch('ALLOWED_LOGIN_EMAILS', '')
     .split(',')
     .map(&:strip)
     .reject(&:empty?)

Rails.logger.info "Allowed login emails whitelist: #{Rails.application.config.allowed_login_emails.size} email(s)"
