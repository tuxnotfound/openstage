class SitemapsController < ApplicationController
  def show
    @users = User.active.order(created_at: :asc)
    @last_entry_at = Entry.visible
                          .where(user: @users)
                          .group(:user_id)
                          .maximum(:occurred_at)

    render layout: false, content_type: "application/xml"
  end
end
