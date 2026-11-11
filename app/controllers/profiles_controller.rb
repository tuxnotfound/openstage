class ProfilesController < ApplicationController
  include CountsPageViews

  def show
    @user = User.active.find_by(username: params[:username])
    unless @user
      return head(:not_found) unless request.format.html?

      @claimed_username = params[:username]
      session[:claimed_username] = @claimed_username
      render :claim
      return
    end

    # The feed never counts a view; the page does, once it runs in a browser.
    @view_ticket = view_ticket(@user) if request.format.html?

    @syncing = syncing?

    @linked = linked_entry

    # Counted as visitors see the page: a project whose builder hides its
    # commits adds none to the entries, nor to the streak below; an entry
    # hidden from the lists still counts. The page is empty only with no
    # public entry at all, as such a project still has its card and its
    # other numbers.
    @total_entries = @user.entries.publicly_counted.without_hidden_commits.count
    @empty = @total_entries.zero? && @user.entries.publicly_counted.none?
    # Public repos only: counting private ones would disclose that they exist.
    @repos_synced  = @user.github_repos.included_repos.public_repos.count
    @milestones    = @user.entries.publicly_counted.where(entry_type: :milestone).count
    # public_activity_streak, not current_streak: the latter counts private
    # entries, so the headline number would disclose private working days.
    @streak        = @user.public_activity_streak

    respond_to do |format|
      format.html { @page = gather }
      # The same de-noised public list the page reads, newest 50, no counts.
      format.rss { @rss_entries = @user.entries.publicly_listed.without_tooling_noise.without_hidden_commits.chronological.limit(50) }
    end
  end

  private

  # Only the owner, only until the first sync has written its log. The page
  # polls itself (see the view) so the history appears without a reload.
  def syncing?
    current_user == @user && @user.sync_logs.where(source: :github).none? && @user.github_access_token.present?
  end

  # A link to one entry shows it at the top, wherever the page would put it.
  def linked_entry
    @user.entries.publicly_listed.without_hidden_commits.find_by(id: params[:entry]) if params[:entry].present?
  end

  # The page opens on the last 30 days, commits and site visits, every
  # project; ?range=, ?show= and ?projects= pick another view (Progress::Filter),
  # and the projects scope the whole page. ?sort=, ?q=, ?live= and ?page= pick
  # the list of the projects past the cards, as its links do without the script.
  def gather
    filter = Progress::Filter.from(params)
    service = Progress::GatherService.new(user: @user, range: filter.range, repos: filter.projects, show: filter.show,
                                          listing: Progress::Listing.from(params))
    service if service.call
  end
end
