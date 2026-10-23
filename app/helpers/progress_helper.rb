module ProgressHelper
  # The public page's own params: the window, and one project or several.
  PROGRESS_PARAMS = [ :range, :repo, { repo: [] } ].freeze
  RANGES = { "30d" => "30 days", "90d" => "90 days", "12m" => "12 months", "all" => "All time" }.freeze
  # Make a card still draws calendar periods; the nearest one to each window.
  CARD_RANGES = { "30d" => "month", "90d" => "month", "12m" => "year", "all" => "all" }.freeze

  # This page with some of its params changed; nil drops one.
  def progress_view_path(user, **changes)
    kept = params.permit(*PROGRESS_PARAMS).to_h.symbolize_keys
    profile_path(user.username, **kept.merge(changes).compact_blank)
  end

  # A project chip's link: the selection with that project switched. With
  # every project in view, switching one leaves the others.
  def progress_chip_path(user, section, project)
    repos = section.tally.projects.all.map(&:repo)
    picked = section.filtered? ? section.selected.map(&:repo) : repos
    picked = picked.include?(project.repo) ? picked - [ project.repo ] : picked + [ project.repo ]
    progress_view_path(user, repo: (picked.empty? || picked.sort == repos.sort ? nil : picked))
  end

  # The class that gives marks a project's colour (bg-(--project) and the
  # like): by rank, the 7th project on grey, and ink for no project.
  def project_class(rank)
    return "os-project-none" if rank.nil?

    rank < ProgressChart::Palette::PROJECT_COLORS[:light].size ? "os-project-#{rank + 1}" : "os-project-other"
  end

  # "all 7 projects", "openstage", "openstage + wheels-off", "3 projects".
  def progress_scope(section)
    return section.selection_name if section.filtered?

    count = section.tally.projects.all.size
    count == 1 ? section.tally.projects.all.first.name : "all #{count} projects"
  end

  # The headline's change: [arrow, words, up?], or [nil, words, nil] with
  # nothing to compare against.
  def progress_change(section)
    now = section.tally.totals.commits
    before = section.tally.previous_totals&.commits
    if before&.positive?
      change = ((100.0 * now / before) - 100).round
      return [ nil, "same as the previous #{Progress::WindowLabels::SPANS.fetch(section.labels.range)}", nil ] if change.zero?

      return [ change.positive? ? "▲" : "▼", "#{change.abs}% #{section.labels.versus}", change.positive? ]
    end
    [ nil, progress_since(section), nil ]
  end

  # "since the first commit, March 26"; "none in the previous 90 days".
  def progress_since(section)
    first = section.tally.first_commit_day
    return "since the first commit, #{first.strftime(first.year == Date.current.year ? '%B %-d' : '%B %-d, %Y')}" if first && section.tally.previous_totals.nil?

    section.tally.previous_totals ? "none in the previous #{Progress::WindowLabels::SPANS.fetch(section.labels.range)}" : ""
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

  # A project card's weekly commits as [line, area] paths in a 400 by 56 box,
  # on the project's own scale.
  def progress_sparkline(weeks)
    high = [ weeks.max.to_i, 1 ].max * 1.1
    points = weeks.each_with_index.map { |n, i| [ i * 400.0 / [ weeks.size - 1, 1 ].max, 56 - (n / high * 56) ] }
    line = points.each_with_index.map { |(x, y), i| "#{i.zero? ? 'M' : 'L'}#{x.round(1)} #{y.round(1)}" }.join(" ")
    [ line, "#{line} L400 56 L0 56 Z" ]
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

  # The post that goes with a card: the period, the card's entries word for
  # word, then the commits.
  def progress_card_draft(section, items)
    labels = section.labels
    period = labels.range == "all" ? labels.subtitle : "#{labels.short}#{' so far' if labels.running?}"
    totals = section.tally.totals
    name = section.selection_name if section.filtered?
    commits = name ? "#{totals.commits} #{name} commits" : pluralize(totals.commits, "commit")
    [ "#{"#{name}, " if name}#{period}:", *items.map(&:title),
      "#{commits} on #{pluralize(totals.active_days, 'day')}." ].join("\n")
  end

  def progress_run_in(item, section)
    names = section.tally.projects.all.map(&:name)
    Progress::RunIn.capped(Progress::RunIn.of(item.title, item.body, names))
  end
end
