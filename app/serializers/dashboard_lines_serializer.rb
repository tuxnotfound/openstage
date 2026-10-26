# The builder's dashboard chart with the lines they switched off left out,
# and the table under it: a row per project, a cell per number with the
# window's value and its switch. A project whose site visits are not counted
# offers to set them up instead.
class DashboardLinesSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include Rails.application.routes.url_helpers

  # lines: a Progress::LinesService; section: its section.
  def initialize(lines, section)
    @lines = lines
    @section = section
  end

  def attributes
    @attributes ||= { chart: ChartSerializer.new(chart).attributes, rows: rows, visits: (number(visits.values.sum) if site) }
  end

  def chart
    ProgressChart::Compare.new(ProgressChart::Trend.new(@section), visits: site&.series || {}, projects: @section.tally.projects,
                                                                   hidden: @lines.hidden)
  end

  # A project with no synced repo behind it has no switches to save.
  def rows
    @section.tally.projects.all.map do |project|
      repo = @lines.repos[project.repo]
      { repo: project.repo, name: project.name, rank: project.rank, switch: (project_dashboard_numbers_path(repo) if repo),
        commits: { value: number(commits.fetch(project.repo, 0)), on: repo.nil? || repo.on_dashboard?("commits"), setup: nil },
        visits: visits_cell(repo) }
    end
  end

  private

  def site
    @lines.site
  end

  def commits
    @section.tally.totals.counts
  end

  # The window's visits per project counted.
  def visits
    @visits ||= site ? site.tally.lines.transform_values(&:sum) : {}
  end

  def visits_cell(repo)
    return { value: nil, on: false, setup: nil } unless repo
    return { value: nil, on: false, setup: edit_project_path(repo, site: "open", anchor: "site-visits") } unless visits.key?(repo.full_name)

    { value: number(visits[repo.full_name]), on: repo.on_dashboard?("visits"), setup: nil }
  end

  def number(value)
    number_with_delimiter(value)
  end
end
