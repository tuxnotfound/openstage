# The landing's demo: a real builder's page over its last 12 months, drawn by
# the same code as the page itself. The landing shows it, and so does the
# card a shared link to the site shows.
module DemoPage
  extend ActiveSupport::Concern

  # The demo opens on its last 12 months, as every page does.
  RANGE = "12m".freeze

  private

  def demo_user
    User.active.find_by(username: ENV.fetch("DEMO_USERNAME", "tuxnotfound"))
  end

  # Nothing to show without a commit in the window.
  def demo_section(user)
    service = Progress::ComposeService.new(user: user, range: RANGE, rolling: true)
    return unless service.call

    service.section if service.section.tally.totals.commits.positive?
  end
end
