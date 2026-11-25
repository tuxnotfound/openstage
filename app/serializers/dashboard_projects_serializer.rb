# The dashboard's list of projects (Projects::DashboardList), as its
# Projects tab draws it and asks for it again: a row per project with its
# name, its colour while it wears one, and its switch, On your stage, which
# saves where it saves today (GithubReposController); past MANY projects,
# the views with their counts, the page, and the app's words for a search
# that finds nothing. No number.
class DashboardProjectsSerializer < ApplicationSerializer
  include Rails.application.routes.url_helpers
  include ActionView::Helpers::NumberHelper

  VIEW_LABELS = { "pinned" => "Pinned", "all" => "All", "hidden" => "Hidden" }.freeze

  def initialize(list)
    @list = list
  end

  # views: [] up to MANY projects; range: nil with none found; empty: why,
  # then; connect: where GitHub connects, for a builder with no project yet,
  # as an empty chart asks (ChartFilterHelper#chart_step).
  def attributes
    shown = @list.shown
    none = @list.count("all").zero?
    { many: @list.many?, count: @list.count("all"), view: @list.view, query: @list.query, page: @list.current_page, pages: @list.pages,
      pinned: @list.count("pinned"), views: views, range: (range(shown) if @list.many? && shown.any?),
      empty: (none ? "Connect your repos to see your commits here." : (empty if shown.empty?)), connect: (new_github_installation_path if none),
      rows: shown.map { |row| row_of(row) } }
  end

  private

  def views
    return [] unless @list.many?

    Projects::DashboardList::VIEWS.map { |key| { key: key, label: VIEW_LABELS.fetch(key), count: number_with_delimiter(@list.count(key)) } }
  end

  def range(shown)
    first = ((@list.current_page - 1) * Projects::DashboardList::PER_PAGE) + 1
    "#{first}–#{first + shown.size - 1} of #{number_with_delimiter(@list.found.size)}"
  end

  # As the stage's list says it (ProjectListSerializer#empty).
  def empty
    kind = [ ("hidden" if @list.view == "hidden"), ("pinned" if @list.view == "pinned"), "project" ].compact.join(" ")
    @list.query.present? ? %(No #{kind} named "#{@list.query}".) : "No #{kind}."
  end

  def row_of(row)
    repo = row.repo
    { id: repo.id, name: repo.name, color_class: @list.color_class(repo), pinned: row.pinned?, stage: repo.included?,
      switch: github_repo_path(repo) }
  end
end
