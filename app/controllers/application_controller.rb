class ApplicationController < ActionController::Base
  include Rememberable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :require_login
  before_action :record_session_start

  helper_method :current_user
  helper_method :current_user_admin?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
    @current_user ||= current_user_from_remember_cookie
  end

  def current_user_admin?
    current_user&.admin?
  end

  def require_admin
    return if current_user_admin?

    redirect_to root_path, alert: "Not authorized."
  end

  def require_login
    return if current_user
    session[:return_to] = request.original_url
    redirect_to login_path, alert: "Please sign in."
  end

  def record_session_start
    return unless current_user
    return if session[:session_start_recorded]

    current_user.record_session_start!
    session[:session_start_recorded] = true
  end
end
