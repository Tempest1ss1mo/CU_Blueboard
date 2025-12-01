require 'securerandom'

class User < ApplicationRecord
  # 1. Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  # 2. Associations
  has_many :posts, dependent: :destroy
  has_many :answers, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_posts, through: :bookmarks, source: :post
  has_many :thread_identities, dependent: :destroy
  has_many :audit_logs, dependent: :destroy
  has_many :performed_audit_logs, class_name: 'AuditLog', foreign_key: :performed_by_id, dependent: :destroy
  has_many :answer_comments, dependent: :destroy
  has_many :post_revisions, dependent: :destroy
  has_many :answer_revisions, dependent: :destroy
  has_many :redacted_posts, class_name: 'Post', foreign_key: :redacted_by_id, dependent: :nullify
  has_many :redacted_answers, class_name: 'Answer', foreign_key: :redacted_by_id, dependent: :nullify

  enum :role, {
    student: 0,
    moderator: 1,
    staff: 2,
    admin: 3
  }, default: :student

  def anonymous_handle
    base = id ? id.to_s(36).upcase.rjust(4, '0') : SecureRandom.alphanumeric(4).upcase
    "Lion ##{base[0, 4]}"
  end

  def can_moderate?
    moderator? || staff? || admin?
  end

  # 3. OmniAuth method with account linking logic
  def self.from_omniauth(auth)
    email = auth.info.email

    # Check if email is in the allowed login emails whitelist (bypass domain check)
    allowed_login_emails = Rails.application.config.allowed_login_emails || []

    # Domain check (skip if email is whitelisted)
    unless allowed_login_emails.include?(email)
      allowed_domains = [ '@columbia.edu', '@barnard.edu' ]
      email_domain = email.match(/@(.+)/)[1] # Extract domain after "@"

      unless allowed_domains.include?("@#{email_domain}")
        return nil # Reject non-campus emails not in whitelist
      end
    end

    # Check moderator whitelist (for all cases)
    moderator_emails = Rails.application.config.moderator_emails || []
    target_role = moderator_emails.include?(auth.info.email) ? :moderator : :student

    # Case 1: User previously signed in with Google
    # Find by provider and uid
    user = User.find_by(provider: auth.provider, uid: auth.uid)
    if user
      # Update role based on current whitelist
      user.update(role: target_role) if user.role.to_s != target_role.to_s
      return user
    end

    # Case 2: Not found. Try to find by email
    # (handles users who registered with email/password first)
    user = User.find_by(email: auth.info.email)
    if user
      # Found! Link Google account by updating provider and uid
      user.update(
        provider: auth.provider,
        uid: auth.uid,
        role: target_role  # Also update role based on whitelist
      )
      return user # Return the linked account
    end

    # Case 3: No user exists in database. Create a new one.
    User.create(
      provider: auth.provider,
      uid: auth.uid,
      email: auth.info.email,
      password: Devise.friendly_token[0, 20],
      role: target_role
    )
  end
end
