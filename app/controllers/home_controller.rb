class HomeController < ApplicationController
  def index
    # A real profile above the fold. The page used to describe a visual product
    # in prose and link the demo in a footnote nobody clicked.
    @demo_user = User.active.find_by(username: ENV.fetch("DEMO_USERNAME", "tuxnotfound"))
    @demo_entries = []

    # Both halves of a page: one entry the builder wrote next to what the sync
    # wrote. A pinned one wins, because the builder chose it. With nothing
    # written by hand, the card falls back to three commits.
    if @demo_user
      shown = @demo_user.entries.publicly_visible
      @demo_highlight = shown.where(entry_type: %w[milestone note released])
                             .order(pinned: :desc, occurred_at: :desc).first
      @demo_entries = shown.where(entry_type: RecapDraft::COMMIT_TYPES).chronological
                           .limit(@demo_highlight ? 2 : 3).to_a
    end

    # No recap example either. The founder's posts are rewritten by hand, so a
    # "ticked commits next to the post" panel could only ever show nothing
    # ticked. The four steps describe the recap; the picker shows it.

    # No global feed here. It sold a network of a handful of people, which is
    # the framing the rebirth dropped; /feed is still one click from a profile.
  end
end
