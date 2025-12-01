# Moderation controller for managing post redactions
module Moderation
  class PostsController < ApplicationController
    before_action :require_moderator!
    before_action :set_post, only: [ :show, :redact, :unredact ]

    # GET /moderation/posts
    # Dashboard listing flagged and redacted posts
    def index
      @redacted_posts = Post.where(redaction_state: [ :redacted, :partial ])
                            .includes(:user, :redacted_by)
                            .order(updated_at: :desc)

      # AI-flagged posts (not yet redacted by human moderators)
      @ai_flagged_posts = Post.where(ai_flagged: true, redaction_state: 'visible')
                              .includes(:user, :redacted_by)
                              .order(updated_at: :desc)
    end

    # GET /moderation/posts/:id
    # Show post details and audit trail
    def show
      @audit_logs = @post.audit_logs.includes(:performed_by).order(created_at: :desc)
    end

    # PATCH /moderation/posts/:id/redact
    # Redact a post
    def redact
      reason = params[:reason].presence || 'policy_violation'
      state = params[:state]&.to_sym || :redacted

      if RedactionService.redact_post(
        post: @post,
        moderator: current_user,
        reason: reason,
        state: state
      )
        redirect_to moderation_posts_path, notice: 'Post has been redacted.'
      else
        redirect_to moderation_posts_path, alert: 'Failed to redact post.'
      end
    end

    # PATCH /moderation/posts/:id/unredact
    # Restore a redacted post
    def unredact
      if RedactionService.unredact_post(
        post: @post,
        moderator: current_user
      )
        redirect_to moderation_posts_path, notice: 'Post has been restored.'
      else
        redirect_to moderation_posts_path, alert: 'Failed to restore post.'
      end
    end

    private

    def set_post
      @post = Post.find(params[:id])
    end
  end
end
