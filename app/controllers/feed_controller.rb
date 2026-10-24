class FeedController < ApplicationController
  SHOWS = { "shipped" => Entry::SHIPPED_TYPES, "posts" => Entry::PUBLISHED_TYPES }.freeze
  PER_PAGE = 40

  # Public: the login wall only hid the one discovery surface from crawlers.
  # Entry.on_feed says whose work it shows.
  def index
    @show = params[:show].presence_in(SHOWS.keys)
    scope = Entry.on_feed.includes(:user).chronological
    # Shipped and Posts are what the builder logged or released, never commits,
    # as What shipped on a builder's page.
    scope = scope.highlights.where(entry_type: SHOWS[@show]) if @show
    # without_count: Load more needs only to know a next page exists, and a
    # count of every public entry grows with the whole table.
    @entries = scope.page(params[:page]).per(PER_PAGE).without_count
  end
end
