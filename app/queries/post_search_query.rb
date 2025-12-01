class PostSearchQuery
  TIMEFRAMES = {
    '24h' => 24.hours,
    '7d' => 7.days,
    '30d' => 30.days
  }.freeze

  def initialize(filters = {})
    @filters = (filters || {}).with_indifferent_access
  end

  def call
    scope = Post.active.includes(:topic, :tags).order(created_at: :desc)
    scope = apply_post_ids(scope)
    scope = apply_author(scope)
    scope = apply_text(scope)
    scope = apply_topic(scope)
    scope = apply_tags(scope)
    scope = apply_status(scope)
    scope = apply_school(scope)
    scope = apply_course(scope)
    scope = apply_timeframe(scope)
    scope
  end

  private

  attr_reader :filters

  def apply_text(scope)
    return scope if filters[:q].blank?

    query = "%#{filters[:q].downcase}%"
    scope.where('LOWER(title) LIKE :query OR LOWER(body) LIKE :query', query: query)
  end

  def apply_topic(scope)
    return scope if filters[:topic_id].blank?

    scope.where(topic_id: filters[:topic_id])
  end

  def apply_tags(scope)
    tag_ids = Array(filters[:tag_ids]).reject(&:blank?)
    return scope if tag_ids.empty?

    scope.joins(:post_tags)
         .where(post_tags: { tag_id: tag_ids })
         .group('posts.id')
         .having('COUNT(DISTINCT post_tags.tag_id) = ?', tag_ids.size)
  end

  def apply_status(scope)
    return scope if filters[:status].blank?

    scope.where(status: filters[:status])
  end

  def apply_school(scope)
    return scope if filters[:school].blank?

    scope.where(school: filters[:school])
  end

  def apply_course(scope)
    return scope if filters[:course_code].blank?

    scope.where('LOWER(course_code) LIKE ?', "%#{filters[:course_code].downcase}%")
  end

  def apply_timeframe(scope)
    timeframe = filters[:timeframe]
    duration = TIMEFRAMES[timeframe]
    return scope unless duration

    scope.where('posts.created_at >= ?', duration.ago)
  end

  def apply_author(scope)
    return scope if filters[:author_id].blank?

    scope.where(user_id: filters[:author_id])
  end

  def apply_post_ids(scope)
    return scope unless filters.key?(:post_ids)

    scope.where(id: filters[:post_ids])
  end
end
