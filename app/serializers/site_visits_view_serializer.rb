# The site visits a chart can draw beside its section's commits, for the same
# window: the window's visits and visitors, their chart on its own, and the
# chart that compares them with commits.
class SiteVisitsViewSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::TextHelper

  # gather: a SiteVisits::GatherService with something to draw; section: its
  # Progress::ComposeService section.
  def initialize(gather, section)
    @gather = gather
    @section = section
  end

  def attributes
    @attributes ||= begin
      tally = @gather.tally
      {
        value: number_with_delimiter(tally.visits), visitors: pluralize(number_with_delimiter(tally.visitors), "visitor"),
        chart: ChartSerializer.new(visits_chart).attributes, compare: ChartSerializer.new(compare_chart).attributes
      }
    end
  end

  def visits_chart
    ProgressChart::SiteVisits.new(@gather.tally, projects: @section.tally.projects)
  end

  def compare_chart
    ProgressChart::Compare.new(ProgressChart::Trend.new(@section), visits: @gather.series, projects: @section.tally.projects)
  end
end
