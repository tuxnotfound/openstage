# The analytics page's tabs (Analytics::Tab) as links, each to its own
# address, to which the page's script adds the window and the projects in
# view; pro: this builder's plan does not open it, so its link wears Pro's
# mark.
class AnalyticsTabsSerializer < ApplicationSerializer
  include Rails.application.routes.url_helpers

  def initialize(user)
    @user = user
  end

  def attributes
    { tabs: Analytics::Tab::ALL.map { |tab| { key: tab.key, label: tab.label, pro: !tab.opens?(@user), path: analytics_path(tab: tab.param) } } }
  end
end
