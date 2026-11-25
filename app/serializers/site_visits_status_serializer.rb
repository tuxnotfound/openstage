# Where the project picked on Set up site visits stands (SiteVisits::Setup):
# its step, the app's line for its first visit once one came, and whether
# its page shows its site visits. The page draws it first
# (SiteVisitsSetupSerializer) and its script asks for it again while it
# waits (Api::SiteVisitsController).
class SiteVisitsStatusSerializer < ApplicationSerializer
  include SiteVisitsHelper

  def initialize(setup)
    @setup = setup
  end

  def attributes
    repo = @setup.repo
    step = @setup.step
    { step: step.to_s, first_visit: ("First visit received #{site_first_visit(repo)}" if step == :done), seen: repo.picks?("visits") }
  end
end
