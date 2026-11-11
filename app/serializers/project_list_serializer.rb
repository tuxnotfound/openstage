# The stage's list of a builder's projects past the ones with a card
# (Progress::ListService), as the stage renders it first
# (profiles/page/_more_projects) and the list's script asks for it
# (Api::ProjectsController): a row per project on the page, with its name,
# its page, its description, whether it is live, and, while visitors see its
# commits, its line of commits per week over the cards' 52 weeks, their
# count and its last commit; and the list's words, which the island and the
# first paint both write. On the builder's dashboard (manage) each row also
# has Edit, whether the stage shows it and its pin, as the chart's table
# has, and each switch sends the list's view (back), so the dashboard comes
# back on it; and it lists the projects hidden from the stage instead
# (hidden), behind a chip of their own while others are listed.
class ProjectListSerializer < ApplicationSerializer
  include Rails.application.routes.url_helpers
  include ProgressHelper

  SORT_LABELS = { "latest" => "Latest", "commits" => "Most commits", "name" => "A–Z" }.freeze

  # list: a called Progress::ListService; user: its builder; manage: their
  # dashboard.
  def initialize(list, user:, manage: false)
    @list = list
    @user = user
    @manage = manage
  end

  # live_label: nil while none is live, and the list offers no filter;
  # hidden_label: nil unless the dashboard lists others beside the hidden.
  # range: nil with no project found; empty: why, then.
  def attributes
    listing = @list.listing
    { title: title, sort: listing.sort, query: listing.query, live: listing.live, hidden: @list.hidden,
      page: @list.page, pages: @list.pages, sorts: Progress::Listing::SORTS.map { |key| { key: key, label: SORT_LABELS.fetch(key) } },
      live_label: ("Live · #{@list.live_count}" if @list.live_count.positive?), hidden_label: hidden_label, range: range,
      empty: (empty if @list.found.zero?), rows: @list.cards.map { |card| row_of(card) }, back: (back if @manage) }
  end

  private

  def title
    return "#{@list.hidden_count} hidden #{'project'.pluralize(@list.hidden_count)}" if @list.hidden

    "#{@list.count} more #{'project'.pluralize(@list.count)}"
  end

  def hidden_label
    "Hidden · #{@list.hidden_count}" if @manage && @list.count.positive? && @list.hidden_count.positive?
  end

  def range
    return if @list.found.zero?

    first = ((@list.page - 1) * Progress::ListService::PER_PAGE) + 1
    "#{first}–#{first + @list.cards.size - 1} of #{@list.found}"
  end

  def empty
    listing = @list.listing
    kind = [ ("hidden" if @list.hidden), ("live" if listing.live), "project" ].compact.join(" ")
    listing.query.present? ? %(No #{kind} named "#{listing.query}".) : "No #{kind}."
  end

  # commits, line: nil while visitors do not see its commits, or it has none
  # in the 52 weeks, and count_words, what a screen reader hears after the
  # count; last: nil while they do not see its commits.
  def row_of(card)
    drawn = card.commits_drawn?
    { key: card.repo, name: card.name, path: project_page_for(@user, card), description: card.description, live: card.live? == true,
      archived: card.archived? == true, commits: (card.commits if drawn), count_words: ("#{'commit'.pluralize(card.commits)} in 12 months" if drawn),
      line: (progress_sparkline(card.weeks).first if drawn), last: (progress_ago(card.last_commit) if card.commits_shown? && card.last_commit) }
      .merge(manage_parts(card.github_repo))
  end

  # A project with no synced repo behind it has nothing to edit or switch.
  # Past the colours, none is pinned; a hidden one takes no pin.
  def manage_parts(repo)
    return { edit: nil, page: nil, pin: nil } unless @manage && repo

    { edit: edit_project_path(repo), page: { on: repo.included?, path: github_repo_path(repo) }, pin: (pin_of(repo) if repo.included?) }
  end

  def pin_of(repo)
    full = @list.colored >= ProgressChart::Palette::SIZE
    { on: false, path: project_pin_path(repo), title: ProjectsTableSerializer.pin_title(on: false, full: full) }
  end

  # What a row's switch sends beside its own: that it came from the list,
  # and the list's view, with the dashboard's prefix. As [name, value] pairs,
  # which keep their names as they leave (ApplicationSerializer).
  def back
    view = @list.listing.with(hidden: @list.hidden, page: @list.page)
    [ [ "back", "list" ], *view.to_params(prefix: Progress::Listing::DASHBOARD).map { |key, value| [ key.to_s, value.to_s ] } ]
  end
end
