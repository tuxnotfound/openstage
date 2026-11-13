# What the landing shows, for HomeController and for a preview that found no
# one, which answers with the landing itself (PreviewsController).
module LandingPage
  extend ActiveSupport::Concern
  include DemoPage

  private

  # A real page above the fold: its headline number, its chart and what it
  # shipped, drawn by the same code as the page itself. Then one recent
  # entry at a time, a sign the product is in use. The whole feed left the
  # landing on 2026-09-29, when it sold a network of a handful of people;
  # one entry at a time shows activity without counting heads.
  def load_landing
    @demo_user = demo_user
    @demo = demo_section(@demo_user) if @demo_user
    @lately = Entry.lately
  end
end
