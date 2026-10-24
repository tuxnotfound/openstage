class HomeController < ApplicationController
  # The demo page opens on its last 12 months, as every page does.
  DEMO_RANGE = "12m".freeze

  def index
    # A real page above the fold: its headline number, its chart and what it
    # shipped, drawn by the same code as the page itself.
    @demo_user = User.active.find_by(username: ENV.fetch("DEMO_USERNAME", "tuxnotfound"))
    @demo = demo_section if @demo_user

    # One recent entry at a time, a sign the product is in use. The whole feed
    # left the landing on 2026-09-29, when it sold a network of a handful of
    # people; one entry at a time shows activity without counting heads.
    @lately = Entry.lately
  end

  private

  # Nothing to show without a commit in the window.
  def demo_section
    service = Progress::ComposeService.new(user: @demo_user, range: DEMO_RANGE, rolling: true)
    return unless service.call

    service.section if service.section.tally.totals.commits.positive?
  end
end
