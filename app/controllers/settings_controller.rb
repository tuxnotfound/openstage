class SettingsController < ApplicationController
  before_action :require_authentication

  def show
  end

  def update
    if current_user.update(profile_params)
      redirect_to settings_path, notice: "Settings saved."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def update_username
    if !current_user.can_change_username?
      redirect_to settings_path, alert: "You can change your username again on #{current_user.next_username_change_at.strftime("%B %-d, %Y")}."
      return
    end

    if current_user.update(username: params.dig(:user, :username))
      redirect_to settings_path, notice: "Username updated."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :show, status: :unprocessable_entity
    end
  end

  def destroy
    current_user.soft_delete!
    session.delete(:user_id)
    redirect_to root_path, notice: "Your account has been scheduled for deletion. You have 30 days to recover it by contacting support."
  end

  private

  def profile_params
    params.require(:user).permit(:display_name, :bio, :website_url, :building_since)
  end
end
