class HomeController < ApplicationController
  def index
    # A real profile above the fold. The page used to describe a visual product
    # in prose and link the demo in a footnote nobody clicked.
    @demo_user = User.active.find_by(username: ENV.fetch("DEMO_USERNAME", "tuxnotfound"))
    @demo_entries = @demo_user ? @demo_user.entries.publicly_visible.chronological.limit(3) : []

    # The recap, shown with the founder's real week and the post that came out
    # of it. Nothing is mocked: no logged post, no section.
    if @demo_user
      @recap_post  = @demo_user.entries.publicly_visible.where(entry_type: :posted)
                               .where.not(body: [ nil, "" ]).order(occurred_at: :desc).first
      @recap_lines = @recap_post ? RecapDraft.for_user(@demo_user, days: 30).candidates.first(40) : []
    end

    @recent_entries = Entry.publicly_visible
                          .joins(:user)
                          .merge(User.active)
                          .includes(:user)
                          .chronological
                          # Capped, not paginated. An infinite scroll here made
                          # everything below the feed unreachable, including the
                          # closing CTA. /feed is where the river belongs.
                          .limit(5)
  end
end
