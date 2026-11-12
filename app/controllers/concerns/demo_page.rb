# The landing's demo: a real builder's page over the window every page opens
# on, drawn by the same code as the page itself. The landing shows it, and so does the
# card a shared link to the site shows.
module DemoPage
  extend ActiveSupport::Concern

  # The username of the builder whose stage is the demo.
  def self.username
    ENV.fetch("DEMO_USERNAME", "tuxnotfound")
  end

  private

  def demo_user
    User.active.find_by(username: DemoPage.username)
  end

  # Nothing to show without a commit in the window. The demo draws its
  # tally as it is, so it counts only the commits visitors see.
  def demo_section(user)
    service = Progress::ComposeService.new(user: user, range: Progress::Window::DEFAULT, rolling: true, shown_only: true)
    return unless service.call

    service.section if service.section.tally.totals.commits.positive?
  end
end
