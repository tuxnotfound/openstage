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
    scope = scope.where(entry_type: SHOWS[@show]) if @show
    @entries = scope.page(params[:page]).per(PER_PAGE)
  end
end
