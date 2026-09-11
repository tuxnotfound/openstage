class ApplicationController < ActionController::Base
  helper_method :current_user, :user_signed_in?

  before_action :capture_first_touch_ref

  private

  # First touch wins: a visitor who arrives from a recap link and signs up three
  # pages later is still attributed to the recap.
  def capture_first_touch_ref
    return if session[:signup_ref].present?
    return if params[:ref].blank?

    session[:signup_ref] = User.normalize_ref(params[:ref])
  end

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
