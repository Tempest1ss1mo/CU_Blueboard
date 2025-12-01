class Post < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :topic
  has_many :answers, dependent: :destroy
  has_many :likes, dependent: :destroy
  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_by_users, through: :bookmarks, source: :user
  has_many :thread_identities, dependent: :destroy
  has_many :audit_logs, as: :auditable, dependent: :destroy
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags
  has_many :post_revisions, dependent: :destroy
  belongs_to :accepted_answer, class_name: 'Answer', optional: true
  belongs_to :redacted_by, class_name: 'User', optional: true

  # Serialize AI moderation data
  serialize :ai_categories, coder: JSON
  serialize :ai_scores, coder: JSON

  after_create :ensure_thread_identity
  after_create_commit :screen_content_async
  scope :active, -> { where('expires_at IS NULL OR expires_at > ?', Time.current) }
  scope :ai_flagged, -> { where(ai_flagged: true) }

  # Constants (must be defined before validations that use them)
  STATUSES = {
    open: 'open',
    solved: 'solved',
    locked: 'locked'
  }.freeze
  TAG_LIMIT = 5
  MIN_TAGS = 1
  SCHOOLS = [ 'Columbia', 'Barnard' ].freeze
  REDACTION_STATES = {
    visible: 'visible',
    partial: 'partial',
    redacted: 'redacted'
  }.freeze
  enum :redaction_state, REDACTION_STATES, default: :visible

  # Validations
  validates :title, presence: true
  validates :body, presence: true
  validates :topic, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES.values }
  validates :school, presence: true, inclusion: { in: SCHOOLS }

  validate :expires_at_within_window
  validate :accepted_answer_belongs_to_post
  validate :tags_within_limit
  validate :redacted_body_presence

  # Status scopes and helper methods
  STATUSES.each do |key, value|
    scope "status_#{key}", -> { where(status: value) }

    define_method("status_#{key}?") do
      status == value
    end
  end

  # Vote helper methods
  def upvotes_count
    likes.upvotes.count
  end

  def downvotes_count
    likes.downvotes.count
  end

  def net_score
    upvotes_count - downvotes_count
  end

  def voted_by?(user)
    user_id = extract_user_id(user)
    return false unless user_id

    likes.exists?(user_id: user_id)
  end

  def find_vote_by(user)
    user_id = extract_user_id(user)
    return nil unless user_id

    likes.find_by(user_id: user_id)
  end

  # Legacy compatibility
  def liked_by?(user)
    vote = find_vote_by(user)
    vote&.upvote? || false
  end

  def find_like_by(user)
    find_vote_by(user)
  end

  # Bookmark helper methods
  def bookmarked_by?(user)
    return false unless user

    bookmarks.exists?(user_id: user.id)
  end

  # Appeal methods
  def request_appeal!
    update!(appeal_requested: true)
  end

  def clear_appeal!
    update!(appeal_requested: false)
  end


  def locked?
    locked_at.present?
  end

  def lock_with(answer)
    update!(accepted_answer: answer, locked_at: Time.current, status: STATUSES[:solved])
  end

  def unlock!
    update!(accepted_answer: nil, locked_at: nil, status: STATUSES[:open])
  end

  # --- SQLite search method (replaces pg_search) ---
  def self.search(query)
    PostSearchQuery.new({ q: query }).call
  end

  def record_revision!(editor:, previous_title:, previous_body:)
    return if previous_title == title && previous_body == body

    post_revisions.create!(user: editor, title: previous_title, body: previous_body)
  end

  private

  def screen_content_async
    # Enqueue background job to screen content with OpenAI Moderation API
    ScreenPostContentJob.perform_later(id)
  end

  def extract_user_id(user)
    return nil unless user
    return user[:id] if user.respond_to?(:[]) && !user.respond_to?(:id)

    user.id
  end

  def ensure_thread_identity
    ThreadIdentity.find_or_create_by!(user: user, post: self)
  end

  def expires_at_within_window
    return if expires_at.blank?

    remaining_days = (expires_at.to_date - Date.current).to_i
    unless remaining_days.between?(7, 30)
      errors.add(:expires_at, 'must be between 7 and 30 days from now')
    end
  end

  def accepted_answer_belongs_to_post
    return if accepted_answer.blank?

    errors.add(:accepted_answer, 'must belong to this post') if accepted_answer.post_id != id
  end

  def tags_within_limit
    count = tag_ids.compact_blank.size
    if count < MIN_TAGS
      errors.add(:tags, 'must include at least one tag')
    elsif count > TAG_LIMIT
      errors.add(:tags, "cannot include more than #{TAG_LIMIT} tags")
    end
  end

  def redacted_body_presence
    return if redaction_state == REDACTION_STATES[:visible]

    if redacted_body.blank?
      errors.add(:redacted_body, 'must be provided when content is redacted')
    end
  end
end
