module ProgressHelper
  # The public page's own params: its chart filter's (Progress::Filter).
  PROGRESS_PARAMS = %i[range show projects].freeze
  RANGES = { "30d" => "30 days", "90d" => "90 days", "12m" => "12 months", "all" => "All time" }.freeze

  # This page with some of its params changed; nil drops one.
  def progress_view_path(user, **changes)
    kept = params.permit(*PROGRESS_PARAMS).to_h.symbolize_keys
    profile_path(user.username, **kept.merge(changes).compact_blank)
  end

  # A project's own page, by the repo's name without its owner. project: a
  # Progress::Projects::Project or a card.
  def project_page_for(user, project, **params)
    project_page_path(user.username, project.repo.split("/").last, **params)
  end

  # The class that gives marks a project's colour (ProgressChart::Palette).
  def project_class(rank)
    ProgressChart::Palette.project_class(rank)
  end

  # "today", "yesterday", "3 days ago", "5 weeks ago", "4 months ago".
  def progress_ago(date, today = Date.current)
    days = (today - date).to_i
    return "today" if days <= 0
    return "yesterday" if days == 1
    return "#{days} days ago" if days < 14
    return "#{(days / 7.0).round} weeks ago" if days < 60

    "#{(days / 30.4).round} months ago"
  end

  # A project card's weekly commits as [line, area] paths in a box 400 by 56
  # unless told otherwise, on the project's own scale.
  def progress_sparkline(weeks, width: 400, height: 56)
    weeks *= 2 if weeks.size == 1
    high = [ weeks.max.to_i, 1 ].max * 1.1
    points = weeks.each_with_index.map { |n, i| [ i * width.to_f / [ weeks.size - 1, 1 ].max, height - (n / high * height) ] }
    line = points.each_with_index.map { |(x, y), i| "#{i.zero? ? 'M' : 'L'}#{x.round(1)} #{y.round(1)}" }.join(" ")
    [ line, "#{line} L#{width} #{height} L0 #{height} Z" ]
  end

  # "+3", "−2" or "±0" against the period before, and whether it went up;
  # nil without one.
  def progress_delta(current, previous)
    return if previous.nil?

    change = current - previous
    text = if change.positive? then "+#{change}" elsif change.negative? then "−#{change.abs}" else "±0" end
    [ text, change.positive? ]
  end

  # "19 entries in 2026 have no project." for the owner's tag line.
  def progress_untagged_line(section)
    count = section.tally.untagged.size
    "#{pluralize(count, 'entry')} #{section.labels.word} #{count == 1 ? 'has' : 'have'} no project" \
      "#{section.filtered? ? ', so this view leaves them out.' : '.'}"
  end

  # The projects a tag row offers first: those in view, then those with
  # commits that day, busiest first.
  def progress_tag_choices(item, section)
    projects = section.tally.projects
    day = section.tally.day_counts.fetch(item.date, {}).select { |repo, _n| repo }.sort_by { |repo, n| [ -n, repo ] }
    choices = section.selected.map { |project| [ project, nil ] }
    choices + day.filter_map do |repo, n|
      project = projects.find(repo)
      [ project, n ] if project && section.selected.exclude?(project)
    end
  end

  def progress_run_in(item, section)
    names = section.tally.projects.all.map(&:name)
    Progress::RunIn.capped(Progress::RunIn.of(item.title, item.body, names))
  end
end
