class SitemapsController < ApplicationController
  def show
    @users = User.active.order(created_at: :asc)
    # publicly_visible: a lastmod derived from private entries would publish a
    # dated signal of private activity that appears nowhere on the profile.
    @last_entry_at = Entry.publicly_visible
                          .where(user: @users)
                          .group(:user_id)
                          .maximum(:occurred_at)
    # Each project page with enough commits to index, dated by its project's
    # last public commit.
    @projects = Entry.publicly_visible.without_tooling_noise.commits
                     .where(user: @users).where.not(repo_name: nil)
                     .group(:user_id, :repo_name)
                     .having("COUNT(*) >= ?", Progress::Projects::INDEXED_COMMITS)
                     .maximum(:occurred_at)
    @posts = BlogPost.all

    render :show, formats: :xml, layout: false, content_type: "application/xml"
  end
end
