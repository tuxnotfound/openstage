# Draws the progress section or one of its cards the way the app does, from
# the design round's data in doc/progress/data.json, to compare with
# doc/progress/shots/. It seeds a builder inside a transaction that is rolled
# back, so nothing is kept, sets the clock to the mocks' day (2026-10-15), and
# writes an HTML page with the fonts and, for the section, the app's stylesheet.
#
#   bin/rails tailwindcss:build
#   bin/rails runner -e test script/progress_render.rb page year bars "$PWD/tmp/page-year.html"
#   bin/rails runner -e test script/progress_render.rb card month lines "$PWD/tmp/card-october.html" dark
#   bin/rails runner -e test script/progress_render.rb card year bars "$PWD/tmp/card-year-500.html" light 500
#   doc/week_cards/tools/htmlshot.sh "$PWD/tmp/page-year.html" tmp/page-year.png 1280 1100
#
# The test database, because the development one may already have a builder
# called tuxnotfound. Days are UTC, as in the mocks.
abort "Never in production." if Rails.env.production?

what, range, chart, out, theme, width = ARGV
unless out && %w[page card].include?(what) && Progress::Period::RANGES.include?(range) && %w[bars lines].include?(chart)
  abort "Usage: bin/rails runner -e test script/progress_render.rb <page|card> <#{Progress::Period::RANGES.join('|')}> " \
        "<bars|lines> <out.html> [light|dark] [width]"
end

require "active_support/testing/time_helpers"
include ActiveSupport::Testing::TimeHelpers

DATA = JSON.parse(Rails.root.join("doc/progress/data.json").read)
HANDLE = "tuxnotfound".freeze

def seed_builder
  abort "A builder is already called #{HANDLE} here; run with -e test." if User.exists?(username: HANDLE)

  User.create!(github_uid: "progress-render", github_username: HANDLE, username: HANDLE, display_name: "Tux", pro: true,
               bio: "currently: relaunching Openstage in public. indie dev. ships things. moves on.",
               avatar_url: "file://#{Rails.root.join('doc/progress/kit/avatar.jpg')}")
end

def repo(index)
  "#{HANDLE}/#{DATA['projects'].fetch(index)}"
end

# Commits and logged entries at noon UTC, so the days match the mocks'.
def seed_entries(user)
  commits = DATA["days"].flat_map do |day, counts|
    counts.flat_map do |index, n|
      Array.new(n) { |k| { user_id: user.id, source: "github", entry_type: "shipped", title: "Commit #{k + 1}", repo_name: repo(index), occurred_at: "#{day} 12:00 UTC" } }
    end
  end
  Entry.insert_all!(commits)
  DATA["entries"].each do |entry|
    Entry.create!(user: user, source: "manual", entry_type: entry["k"] == "s" ? "milestone" : "posted", title: entry["t"], body: entry["b"],
                  pinned: entry["pin"] == 1, repo_name: entry["r"] && repo(entry["r"]), occurred_at: "#{entry['d']} 12:00 UTC")
  end
end

def fonts_css
  CardText::FONTS.select { |font| CardLayout::Footnotes::FAMILIES.include?(font[:family]) }.map do |font|
    "@font-face{font-family:'#{font[:family]}';font-style:#{font[:style]};font-weight:#{font[:weight]};" \
      "src:url('file://#{Rails.root.join('app/assets/fonts', font[:file])}') format('woff2')}"
  end.join
end

def page(body, width, stylesheet: false)
  css = stylesheet ? "<link rel=\"stylesheet\" href=\"file://#{Rails.root.join('app/assets/builds/tailwind.css')}\">" : ""
  size = width ? "svg{width:#{width.to_i}px;height:auto}" : ""
  "<!doctype html><html><head><meta charset=\"utf-8\">#{css}<style>#{fonts_css}" \
    "html,body{margin:0;padding:0;background:#fff}svg{display:block}#{size}</style></head><body>#{body}</body></html>"
end

def section_html(section, chart)
  renderer = ApplicationController.renderer.new("QUERY_STRING" => { range: section.labels.range, chart: chart }.to_query)
  html = renderer.render(partial: "profiles/progress/section", locals: { user: section.tally.user, section: section })
  "<main class=\"max-w-5xl mx-auto px-4 py-8\">#{html}</main>"
end

ActiveRecord::Base.transaction do
  user = seed_builder
  seed_entries(user)
  travel_to(Time.utc(2026, 10, 15, 12)) do
    section = Progress::ComposeService.new(user: user, range: range).tap(&:call!).section
    html = if what == "page"
      page(section_html(section, chart), nil, stylesheet: true)
    else
      layout = (chart == "lines" ? CardLayout::Journey : CardLayout::Footnotes).new(section, user: user, theme: theme || "light")
      page(ApplicationController.render(partial: "progress_cards/#{chart == 'lines' ? 'journey' : 'footnotes'}", locals: { layout: layout }), width)
    end
    File.write(out, html)
  end
  puts out
  raise ActiveRecord::Rollback
end
