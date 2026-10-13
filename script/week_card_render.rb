# Draws a week card the way the app does, from the real weeks in
# doc/week_cards/mocks/data.json, to compare with the approved mocks. It seeds a
# builder and their weeks inside a transaction that is rolled back, so nothing
# is kept, and writes an HTML page with the template's fonts and the avatar.
#
#   bin/rails runner -e test script/week_card_render.rb changelog w41 light "$PWD/tmp/changelog-w41-light.html"
#   doc/week_cards/tools/htmlshot.sh "$PWD/tmp/changelog-w41-light.html" tmp/changelog-w41-light.png
#
# The test database, because the development one may already have a builder
# called tuxnotfound. Times are UTC, and the card's zone is too.
abort "Never in production." if Rails.env.production?

template_key, week_key, theme, out = ARGV
WEEKS = %w[w41 w40 w38].freeze
unless out && WeekCardTemplate.keys.include?(template_key) && WEEKS.include?(week_key) && WeekCard::THEMES.include?(theme)
  abort "Usage: bin/rails runner -e test script/week_card_render.rb <#{WeekCardTemplate.keys.join('|')}> " \
        "<#{WEEKS.join('|')}> <#{WeekCard::THEMES.join('|')}> <out.html>"
end

DATA = JSON.parse(Rails.root.join("doc/week_cards/mocks/data.json").read)
BUILDER = DATA.fetch("builder")
# data.json does not say which of a day's commits went to which project. The
# Star Chart mock hands each day's hours to its projects in this order where it
# differs from data.json's, so the stars take the same colours.
HOUR_ORDER = { "w41" => { 4 => %w[trained-on openstage] }, "w40" => { 0 => %w[openstage trained-on] },
               "w38" => { 1 => %w[story_time_v1 openstage] } }.freeze
# When each Friday post went out, also from the Star Chart mock: data.json has
# no times for what was logged.
POST_HOUR = { "w41" => 16, "w40" => 18, "w38" => 20 }.freeze
# The line the app writes for a post on X. data.json lists it as the day's
# headline; here it comes from the post itself, as in the app.
POSTED_ON_X = "Posted on X".freeze

def at(date, hour, minute = 0)
  Time.utc(date.year, date.month, date.day, hour, minute)
end

# n split over count parts, the remainder going to the first ones.
def share(total, count, index)
  (total / count) + (index < total % count ? 1 : 0)
end

def seed_builder
  abort "A builder is already called #{BUILDER['github']} here; run with -e test." if User.exists?(username: BUILDER["github"])

  User.create!(github_uid: "week-card-render", github_username: BUILDER["github"], username: BUILDER["github"],
               display_name: BUILDER["name"], pro: BUILDER["pro"], building_since: Date.parse(BUILDER["building_since"]),
               avatar_url: "file://#{Rails.root.join('doc/week_cards/assets/avatar.jpg')}")
end

def commit(user, project, time, title)
  Entry.create!(user: user, source: "github", entry_type: "shipped", title: title,
                repo_name: "#{BUILDER['github']}/#{project}", occurred_at: time)
end

def post(user, date, hour)
  Entry.create!(user: user, source: "manual", entry_type: "posted", title: "Week #{date.cweek} on X",
                url: "https://x.com/#{BUILDER['x']}/status/#{date.strftime('%Y%m%d')}", occurred_at: at(date, hour))
end

def seed_day(user, key, date, index, day)
  order = HOUR_ORDER.dig(key, index) || day["commits"].keys
  owners = order.flat_map { |project| [ project ] * day["commits"].fetch(project) }
  day["hours"].each_with_index.map do |hour, k|
    commit(user, owners[k], at(date, hour, (k * 7) % 60), "Commit #{k + 1} on #{owners[k]}")
  end
end

# The week's lines and files, spread over its commits; its languages on the
# first, by share, leaving out data.json's "other".
def spread_code(commits, code)
  return if commits.empty? || code.nil?

  languages = code["languages"].reject { |name, _percent| name == "other" }.to_h { |name, percent| [ name, percent * 10 ] }
  commits.each_with_index do |entry, i|
    entry.update!(additions: share(code["added"], commits.size, i), deletions: share(code["removed"], commits.size, i),
                  files_changed: share(code["files"], commits.size, i), languages: i.zero? ? languages : {},
                  stats_fetched_at: Time.current)
  end
end

# The builder's own words for a day, as the editor saves them: never a count
# line the app wrote, nor the line a post gives itself.
def headlines(monday, week)
  week["days"].each_with_index.filter_map do |day, i|
    next if day["headline"].blank? || day["headline_is_auto_count"] || day["headline"] == POSTED_ON_X

    [ (monday + i).iso8601, { "text" => day["headline"], "kind" => day["kind"] } ]
  end.to_h
end

def seed_week(user, key, week)
  monday = WeekCard.week_start_for(week["iso"])
  commits = week["days"].each_with_index.flat_map { |day, i| seed_day(user, key, monday + i, i, day) }
  spread_code(commits, week["code"])
  week["days"].each_with_index { |day, i| post(user, monday + i, POST_HOUR[key]) if day["headline"] == POSTED_ON_X }
  WeekCard.create!(user: user, week_start: monday, time_zone: "UTC", headlines: headlines(monday, week),
                   next_goal: week["next_week_goal"])
end

# A week data.json only totals, the one before w40 or w38, so those cards can
# say what changed: its commits over its first active days, and its posts and
# launches on those days.
def seed_totals(user, monday, totals)
  totals["active_days"].times do |i|
    share(totals["commits"], totals["active_days"], i).times do |k|
      commit(user, "openstage", at(monday + i, 10 + (k % 12), (k * 7) % 60), "Earlier commit #{k + 1}")
    end
  end
  totals["published"].times { |i| post(user, monday + i, 18) }
  totals["shipped"].times do |i|
    Entry.create!(user: user, source: "manual", entry_type: "milestone", title: "Launch #{i + 1}", occurred_at: at(monday + i, 12))
  end
end

def page(template, svg)
  faces = template.fonts.map do |font|
    "@font-face{font-family:'#{font[:family]}';font-style:#{font[:style]};font-weight:#{font[:weight]};" \
      "src:url('file://#{Rails.root.join('app/assets/fonts', font[:file])}') format('woff2')}"
  end
  "<!doctype html><html><head><meta charset=\"utf-8\"><style>#{faces.join}" \
    "html,body{margin:0;padding:0;overflow:hidden}svg{display:block}</style></head><body>#{svg}</body></html>"
end

ActiveRecord::Base.transaction do
  user = seed_builder
  weeks = DATA.fetch("weeks")
  mondays = weeks.values.map { |week| WeekCard.week_start_for(week["iso"]) }
  weeks.each do |key, week|
    seed_week(user, key, week)
    before = WeekCard.week_start_for(week["iso"]) - 7
    seed_totals(user, before, week["previous_week"]) unless mondays.include?(before)
  end

  card = WeekCard.find_by!(user: user, week_start: WeekCard.week_start_for(weeks.fetch(week_key)["iso"]))
  card.update!(style: template_key, theme: theme)
  compose = WeekCards::ComposeService.new(week_card: card)
  compose.call!
  svg = ApplicationController.render(partial: card.template.partial, locals: { card: compose.card })
  File.write(out, page(card.template, svg))
  puts out
  raise ActiveRecord::Rollback
end
