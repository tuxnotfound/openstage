class FeedController < ApplicationController
  SHOWS = { "shipped" => Entry::SHIPPED_TYPES, "posts" => Entry::PUBLISHED_TYPES }.freeze

  # Public: the login wall only hid the one discovery surface from crawlers.
  # Entry.on_feed says whose work it shows; Feed::ListService, as what.
  def index
    @show = params[:show].presence_in(SHOWS.keys)
    scope = Entry.on_feed
    # Shipped and Posts are what the builder logged or released, never commits,
    # as What's new on a builder's page.
    scope = scope.highlights.where(entry_type: SHOWS[@show]) if @show
    @feed = Feed::ListService.new(scope:, before: params[:before], builder: params[:builder])
    head :bad_request unless @feed.call
  end
end
