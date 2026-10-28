# The builder's dashboard chart with the lines they switched off left out,
# and the table under it: a row per project, with Edit, whether the
# builder's page shows it, and a cell per number with the window's value and
# its switch. A project whose site visits are not counted offers to set them
# up instead; one hidden from the page comes last, with no line to draw.
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

  # A project with no synced repo behind it has nothing to edit or save.
  def rows
    shown = @section.tally.projects.all.map do |project|
      repo = @lines.repos[project.repo]
      row(project.repo, project.name, project.rank, repo).merge(
        commits: { value: number(commits.fetch(project.repo, 0)), on: repo.nil? || repo.shows?("commits"), setup: nil },
        visits: visits_cell(repo)
      )
    end
    shown + @lines.off_page.map { |repo| row(repo.full_name, repo.name, nil, repo).merge(commits: empty_cell, visits: empty_cell) }
  end

  private

  def row(full_name, name, rank, repo)
    { repo: full_name, name: name, rank: rank, edit: (edit_project_path(repo) if repo), switch: (project_numbers_path(repo) if repo),
      page: ({ on: repo.included?, path: github_repo_path(repo) } if repo) }
  end

  def empty_cell
    { value: nil, on: false, setup: nil }
  end

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
    return empty_cell unless repo
    return { value: nil, on: false, setup: edit_project_path(repo, site: "open", anchor: "site-visits") } unless visits.key?(repo.full_name)

    { value: number(visits[repo.full_name]), on: repo.shows?("visits"), setup: nil }
  end

  def number(value)
    number_with_delimiter(value)
  end
end
