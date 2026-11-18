# A tab Free does not open (Analytics::Tab#opens?), as the page shows it:
# the page's tabs, what the tab shows on Pro (pitch), and the dashboard's
# button to Pro, which posts to checkout; nothing of its numbers, and no
# window.
class AnalyticsLockedSerializer < ApplicationSerializer
  include Rails.application.routes.url_helpers

  def initialize(user, tab)
    @user = user
    @tab = tab
  end

  def attributes
    { locked: true, tab: @tab.key, **AnalyticsTabsSerializer.new(@user).attributes, pitch: @tab.pitch,
      checkout: { label: "Go Pro for $7 a month", path: checkout_path } }
  end
end
