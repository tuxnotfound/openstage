class ProfilesController < ApplicationController
  def show
    @user = User.find_by(username: params[:username])
    unless @user
      render file: Rails.root.join("public/404.html"), status: :not_found, layout: false
      return
    end

    @entries = @user.entries.visible.chronological
  end
end
