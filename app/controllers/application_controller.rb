class ApplicationController < ActionController::Base
  helper_method :current_user, :user_signed_in?

  private

  # defined? rather than ||= so the nil results cache too; otherwise every
  # current_user call in a layout re-queries.
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = begin
      user = session[:user_id] && User.find_by(id: session[:user_id])
      user unless user.nil? || user.deleted?
    end
  end

  def user_signed_in?
    current_user.present?
  end

  def require_authentication
    redirect_to root_path, alert: "Please sign in first." unless user_signed_in?
  end
end
