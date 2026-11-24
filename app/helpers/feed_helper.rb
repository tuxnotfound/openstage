module FeedHelper
  # "3 commits · 1 shipped · today", for a Feed::ListService::Card.
  def feed_summary(card)
    parts = [ (pluralize(card.commits, "commit") if card.commits.positive?), ("#{card.shipped} shipped" if card.shipped.positive?),
              ("#{card.published} published" if card.published.positive?) ]
    (parts.compact << feed_day(card.date)).join(" · ")
  end

  def feed_day(date)
    return "today" if date == Date.current
    return "yesterday" if date == Date.yesterday

    date.strftime(date.year == Date.current.year ? "%b %-d" : "%b %-d, %Y")
  end

  # A builder's colour on the feed, the same one on every visit: one of the
  # project colours, by their id.
  def feed_color(user)
    ProgressChart::Palette.project_class(user.id % ProgressChart::Palette::PROJECT_COLORS[:light].size)
  end
end
