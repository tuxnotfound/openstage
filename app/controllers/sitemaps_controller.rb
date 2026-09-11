class SitemapsController < ApplicationController
  def show
    @users = User.active.order(created_at: :asc)
    # publicly_visible: a lastmod derived from private entries would publish a
    # dated signal of private activity that appears nowhere on the profile.
    @last_entry_at = Entry.publicly_visible
                          .where(user: @users)
                          .group(:user_id)
                          .maximum(:occurred_at)
    @posts = BlogPost.all

    render :show, formats: :xml, layout: false, content_type: "application/xml"
  end
end
