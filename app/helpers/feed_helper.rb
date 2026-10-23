module FeedHelper
  # Entries on one builder's day, newest first.
  FeedGroup = Data.define(:user, :date, :entries)

  # A page of the feed as one card per builder and day, so one busy builder
  # takes one card.
  def feed_groups(entries)
    entries.chunk_while { |a, b| a.user_id == b.user_id && a.occurred_at.to_date == b.occurred_at.to_date }
           .map { |run| FeedGroup.new(user: run.first.user, date: run.first.occurred_at.to_date, entries: run) }
  end

  # "3 commits · 1 shipped · today"
  def feed_summary(group)
    commits, others = group.entries.partition(&:commit?)
    shipped, posts = others.partition { |entry| Entry::SHIPPED_TYPES.include?(entry.entry_type) }
    parts = [ (pluralize(commits.size, "commit") if commits.any?), ("#{shipped.size} shipped" if shipped.any?),
              ("#{posts.size} published" if posts.any?) ]
    (parts.compact << feed_day(group.date)).join(" · ")
  end

  def feed_day(date)
    return "today" if date == Date.current
    return "yesterday" if date == Date.yesterday

    date.strftime(date.year == Date.current.year ? "%b %-d" : "%b %-d, %Y")
  end

  # A builder's colour on the feed, the same one on every visit.
  def feed_color(user)
    project_class(user.id % ProgressChart::Palette::PROJECT_COLORS[:light].size)
  end
end
