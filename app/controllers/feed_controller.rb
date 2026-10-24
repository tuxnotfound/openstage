class FeedController < ApplicationController
  SHOWS = { "shipped" => Entry::SHIPPED_TYPES, "posts" => Entry::PUBLISHED_TYPES }.freeze
  PER_PAGE = 40

  # Public: the homepage already renders this same feed to signed-out visitors,
  # so the login wall only hid the one discovery surface from crawlers. Every
  # builder's public work but the owner's, so it shows the others; merges and
  # dependency bumps left out, as on every page.
  def index
    @show = params[:show].presence_in(SHOWS.keys)
    scope = Entry.publicly_visible.without_tooling_noise.joins(:user).merge(User.active.not_owner).includes(:user).chronological
    # Shipped and Posts are what the builder logged or released, never commits,
    # as What shipped on a builder's page.
    scope = scope.highlights.where(entry_type: SHOWS[@show]) if @show
    # without_count: Load more needs only to know a next page exists, and a
    # count of every public entry grows with the whole table.
    @entries = scope.page(params[:page]).per(PER_PAGE).without_count
  end
end
