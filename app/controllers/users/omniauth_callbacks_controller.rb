class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def google_oauth2
    # 1. Call the logic in User model
    @user = User.from_omniauth(request.env['omniauth.auth'])

    if @user.present?
      # 2A. Login success (valid campus email)
      sign_in_and_redirect @user, event: :authentication
      set_flash_message(:notice, :success, kind: 'Google') if is_navigational_format?
    else
      # 2B. Login failed (non-campus email)
      # @user returned nil from User.from_omniauth
      flash[:alert] = 'Access Denied. You must use a @columbia.edu or @barnard.edu email address to log in.'
      redirect_to unauthenticated_root_path
    end
  end

  def failure
    flash[:alert] = 'Google sign-in failed. Please try again.'
    redirect_to unauthenticated_root_path
  end
end
