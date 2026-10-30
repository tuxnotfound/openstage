class SitemapsController < ApplicationController
  def show
    @users = User.active.order(created_at: :asc)
    # publicly_visible: a lastmod derived from private entries would publish a
    # dated signal of private activity that appears nowhere on the profile;
    # so would one from the commits a builder hides from visitors.
    @last_entry_at = Entry.publicly_visible.without_hidden_commits
                          .where(user: @users)
                          .group(:user_id)
                          .maximum(:occurred_at)
    # Each project page with enough commits to index, dated by its project's
    # last public commit, and undated while its builder hides its commits,
    # read in the same pass.
    @projects = Entry.publicly_visible.without_tooling_noise.commits
                     .where(user: @users).where.not(repo_name: nil).group(:user_id, :repo_name)
                     .having("COUNT(*) >= ?", Progress::Projects::INDEXED_COMMITS)
                     .pluck(:user_id, :repo_name, Arel.sql("MAX(entries.occurred_at) FILTER (WHERE #{Entry::HIDDEN_COMMITS_SQL})"))
    @posts = BlogPost.all

    render :show, formats: :xml, layout: false, content_type: "application/xml"
  end
end
