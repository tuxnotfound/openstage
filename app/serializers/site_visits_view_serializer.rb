# A project's site visits beside its commits on its page, for the same
# window: the tab's number, the visitors under it, and the chart.
class SiteVisitsViewSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper

  # tally: a SiteVisits::TallyService; name and rank: the project's.
  def initialize(tally, name:, rank:)
    @tally = tally
    @name = name
    @rank = rank
  end

  def attributes
    {
      value: number_with_delimiter(@tally.visits), visitors: pluralize(number_with_delimiter(@tally.visitors), "visitor"),
      chart: ChartSerializer.new(ProgressChart::SiteVisits.new(@tally, name: @name, rank: @rank)).attributes
    }
  end
end
