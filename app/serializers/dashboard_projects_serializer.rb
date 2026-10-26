# The table under the dashboard's chart, a row per project: Edit, whether the
# chart draws it, whether the builder's page shows it, and its value in the
# window for every number. Site visits are always a column, so a project that
# counts none offers to set them up; a project hidden from the page comes
# last, with nothing to draw.
class DashboardProjectsSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include Rails.application.routes.url_helpers

  COLUMNS = { "commits" => "Commits", "visits" => "Site visits" }.freeze

  # list: a Projects::ListService; numbers: the section's Progress::NumbersService.
  def initialize(list, section, numbers)
    @list = list
    @section = section
    @numbers = numbers.numbers.index_by(&:key)
  end

  def attributes
    @attributes ||= { columns: COLUMNS.map { |key, label| { key: key, label: label } }, rows: shown + hidden }
  end

  private

  # chart: the chart draws it, which every project does until some are picked.
  def shown
    @section.tally.projects.all.map do |project|
      repo = @list.repos[project.repo]
      row(project.repo, project.name, project.rank, repo).merge(
        chart: !@section.filtered? || @section.selected.include?(project),
        values: COLUMNS.keys.index_with { |key| value(key, project.repo) },
        setup: (edit_project_path(repo, site: "open", anchor: "site-visits") if repo && value("visits", project.repo).nil?)
      )
    end
  end

  def hidden
    @list.off_page.map do |repo|
      row(repo.full_name, repo.name, nil, repo).merge(chart: nil, values: COLUMNS.keys.index_with { nil }, setup: nil)
    end
  end

  def row(full_name, name, rank, repo)
    { repo: full_name, name: name, rank: rank, edit: (edit_project_path(repo) if repo),
      page: ({ on: repo.included?, path: github_repo_path(repo) } if repo) }
  end

  # nil for a number the project does not have; every project has commits.
  def value(key, repo)
    count = @numbers[key]&.by_project&.[](repo)
    count ||= 0 if key == "commits"
    number_with_delimiter(count) if count
  end
end
