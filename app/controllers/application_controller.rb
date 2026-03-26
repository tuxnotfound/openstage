class ApplicationController < ActionController::Base
  helper_method :current_user, :user_signed_in?

  private

  def current_user
    return nil unless session[:user_id]
    user = User.find_by(id: session[:user_id])
    return nil if user&.deleted?
    @current_user ||= user
  end

  def user_signed_in?
    current_user.present?
  end

  def require_authentication
    redirect_to root_path, alert: "Please sign in first." unless user_signed_in?
  end
end
