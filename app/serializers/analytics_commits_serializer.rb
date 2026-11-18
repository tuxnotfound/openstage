# The Commits tab's own parts (Analytics::CommitParts), for its window and
# the projects in view: Active days, a figure with the days it counts of;
# the table's Last commit column, worded as the dashboard's list of
# projects words it; when the builder commits, a row per weekday, Monday
# first, and a cell per hour, each with its words and its step, 0 for none,
# then 1 to 4 by quarters of the busiest cell; and what's new, newest
# first, each entry with its mark, its project's colour and name, and its
# day, or with none, the stage's own line.
class AnalyticsCommitsSerializer < ApplicationSerializer
  include ActionView::Helpers::NumberHelper
  include ProgressHelper

  DAYS = %w[Mon Tue Wed Thu Fri Sat Sun].freeze
  STEPS = 4

  # report: an Analytics::ReportService with its commit_parts.
  def initialize(report)
    @report = report
    @parts = report.commit_parts
  end

  def attributes
    { hours: hours, news: @parts.news.map { |item| news_item(item) }, news_empty: @report.totals_window.labels.empty }
  end

  # A tile as ChartFilterSerializer#number_of writes one, with no change
  # and no split.
  def tile
    { key: "active_days", label: "Active days", word: "active days", group: "On GitHub", value: number_with_delimiter(@parts.active),
      split: [], change: nil, figure: true, suffix: "of #{number_with_delimiter(@parts.days)}" }
  end

  # The column's label, and each row's words by key, nil with no commit.
  def last_commits
    today = @report.totals_window.today
    { label: "Last commit", values: @report.rows.to_h { |row| [ row.key, (day = @parts.last_commit(row.key)) && progress_ago(day, today) ] } }
  end

  private

  def hours
    counts = @parts.hours
    most = counts.values.max
    DAYS.each_with_index.map do |name, day|
      { name: name, cells: Array.new(24) { |hour| cell(name, hour, counts.fetch([ day, hour ], 0), most) } }
    end
  end

  def cell(name, hour, count, most)
    { step: count.zero? ? 0 : (count * STEPS.to_f / most).ceil, title: "#{name} #{format('%02d', hour)}:00, #{number_with_delimiter(count)} #{'commit'.pluralize(count)}" }
  end

  def news_item(item)
    row = @report.rows.find { |each| each.key == item.repo_name }
    { id: item.id, date: item.date.strftime("%b %-d"), badge: item.badge.to_s, kind: ProgressHelper::BADGE_WORDS.fetch(item.badge),
      color_class: row&.color_class || ProgressChart::Palette::INK_CLASS, title: item.title, project: row&.name }
  end
end
