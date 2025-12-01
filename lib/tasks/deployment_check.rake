# frozen_string_literal: true

namespace :deployment do
  desc 'Verify application is ready for production'
  task check: :environment do
    puts "\n=== CU BlueBoard Deployment Check ===\n\n"

    errors = []
    warnings = []

    # 1. Check seed data
    puts 'Checking seed data...'
    topic_count = Topic.count
    tag_count = Tag.count

    if topic_count.zero?
      errors << 'CRITICAL: No topics in database. Run: rails db:seed'
    else
      puts "  Topics: #{topic_count} found"
    end

    if tag_count.zero?
      errors << 'CRITICAL: No tags in database. Posts cannot be created. Run: rails db:seed'
    else
      puts "  Tags: #{tag_count} found"
    end

    # 2. Check environment variables
    puts "\nChecking environment variables..."

    required_vars = {
      'GOOGLE_OAUTH2_CLIENT_ID' => 'Google OAuth authentication',
      'GOOGLE_OAUTH2_CLIENT_SECRET' => 'Google OAuth authentication'
    }

    optional_vars = {
      'OPENAI_API_KEY' => 'AI content moderation (optional)',
      'MODERATOR_EMAILS' => 'Moderator whitelist'
    }

    required_vars.each do |var, purpose|
      if ENV[var].blank?
        errors << "CRITICAL: #{var} not set (required for #{purpose})"
      else
        puts "  #{var}: configured"
      end
    end

    optional_vars.each do |var, purpose|
      if ENV[var].blank?
        warnings << "WARNING: #{var} not set (#{purpose})"
      else
        puts "  #{var}: configured"
      end
    end

    # 3. Check moderator configuration
    puts "\nChecking moderator configuration..."
    moderator_emails = Rails.application.config.moderator_emails rescue []

    if moderator_emails.empty?
      warnings << 'WARNING: No moderator emails configured. Moderation features will be limited.'
    else
      puts "  Moderator emails: #{moderator_emails.count} configured"
      moderator_emails.first(3).each { |email| puts "    - #{email}" }
      puts "    - ... and #{moderator_emails.count - 3} more" if moderator_emails.count > 3
    end

    # 4. Check database connectivity
    puts "\nChecking database..."
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      puts '  Database connection: OK'
      puts "  Users: #{User.count}"
      puts "  Posts: #{Post.count}"
    rescue StandardError => e
      errors << "CRITICAL: Database connection failed: #{e.message}"
    end

    # 5. Summary
    puts "\n=== Summary ===\n"

    if errors.any?
      puts "\nERRORS (must fix):"
      errors.each { |e| puts "  - #{e}" }
    end

    if warnings.any?
      puts "\nWARNINGS (may affect functionality):"
      warnings.each { |w| puts "  - #{w}" }
    end

    if errors.empty? && warnings.empty?
      puts "\nAll checks passed. Application is ready for deployment."
    elsif errors.empty?
      puts "\nNo critical errors. Review warnings before deploying."
    else
      puts "\nCritical errors found. Fix before deploying."
      exit 1
    end
  end

  desc 'Fix common deployment issues by running seeds'
  task fix: :environment do
    puts 'Running db:seed to create required data...'
    Rake::Task['db:seed'].invoke

    puts "\nRe-running deployment check..."
    Rake::Task['deployment:check'].invoke
  end
end
