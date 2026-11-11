# The stage's list of a builder's projects past the ones with a card
# (Progress::ListService), as the stage renders it first
# (profiles/page/_more_projects) and the list's script asks for it
# (Api::ProjectsController): a row per project on the page, with its name,
# its page, its description, whether it is live, and, while visitors see its
# commits, its line of commits per week over the cards' 52 weeks, their
# count and its last commit; and the list's words, which the island and the
# first paint both write.
class ProjectListSerializer < ApplicationSerializer
  include Rails.application.routes.url_helpers
  include ProgressHelper

  SORT_LABELS = { "latest" => "Latest", "commits" => "Most commits", "name" => "A–Z" }.freeze

  # list: a called Progress::ListService; user: its builder.
  def initialize(list, user:)
    @list = list
    @user = user
  end

  # live_label: nil while none is live, and the list offers no filter.
  # range: nil with no project found; empty: why, then.
  def attributes
    listing = @list.listing
    { title: "#{@list.count} more #{'project'.pluralize(@list.count)}", sort: listing.sort, query: listing.query, live: listing.live,
      page: @list.page, pages: @list.pages, sorts: Progress::Listing::SORTS.map { |key| { key: key, label: SORT_LABELS.fetch(key) } },
      live_label: ("Live · #{@list.live_count}" if @list.live_count.positive?), range: range, empty: (empty if @list.found.zero?),
      rows: @list.cards.map { |card| row_of(card) } }
  end

  private

  def range
    return if @list.found.zero?

    first = ((@list.page - 1) * Progress::ListService::PER_PAGE) + 1
    "#{first}–#{first + @list.cards.size - 1} of #{@list.found}"
  end

  def empty
    listing = @list.listing
    kind = listing.live ? "live project" : "project"
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
  end
end
