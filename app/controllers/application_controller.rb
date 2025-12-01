class ApplicationController < ActionController::Base
  # Global authentication requirement for all pages
  # Devise login/registration pages are automatically excluded
  before_action :authenticate_user!

  protected

  # Require moderator, staff, or admin role
  # Note: authenticate_user! runs globally, so current_user is never nil here
  def require_moderator!
    unless current_user.can_moderate?
      redirect_to root_path, alert: 'Access denied. Moderator privileges required.'
    end
  end

  # Require staff or admin role
  def require_staff!
    unless current_user.staff? || current_user.admin?
      redirect_to root_path, alert: 'Access denied. Staff privileges required.'
    end
  end

  # Require admin role only
  def require_admin!
    unless current_user.admin?
      redirect_to root_path, alert: 'Access denied. Administrator privileges required.'
    end
  end
end
