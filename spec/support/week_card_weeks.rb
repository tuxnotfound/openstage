# A week of a builder's work, seeded and composed as the editor would draw it,
# for the layout specs of the week card templates.
module WeekCardWeeks
  # days: from Monday, each with its commits by project, the hours they
  # landed at (handed out to the projects in order, noon without), and the
  # builder's words and kind. posts: the days a post was logged, at 18:00 or
  # at { day => hour }.
  def seed_week(user, monday, days, posts: [])
    days.each_with_index do |day, i|
      owners = day.fetch(:commits, {}).flat_map { |project, n| [ project ] * n }
      owners.each_with_index do |project, k|
        hour = day.fetch(:hours, [])[k] || 12
        create(:entry, user: user, source: "github", entry_type: "shipped", repo_name: "me/#{project}",
                       occurred_at: (monday + i).to_time(:utc) + hour.hours + k.minutes)
      end
    end
    posts.to_h { |post| post.is_a?(Array) ? post : [ post, 18 ] }.each do |i, hour|
      create(:entry, user: user, source: "manual", entry_type: "posted", title: "A post", occurred_at: (monday + i).to_time(:utc) + hour.hours)
    end
  end

  def compose_week(user, monday, days, goal: nil, sections: {}, layout: "week", theme: "light")
    week_card = WeekCard.new(user: user, week_start: monday, next_goal: goal, layout: layout, theme: theme, time_zone: "UTC")
    week_card.headlines = days.each_with_index.to_h { |day, i| [ (monday + i).iso8601, { "text" => day[:words].to_s, "kind" => day[:kind] } ] }
    week_card.sections = sections
    WeekCards::ComposeService.new(week_card: week_card).tap(&:call!).card
  end
end
