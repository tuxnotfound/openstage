require "rails_helper"

RSpec.describe "The dashboard's activity and projects", type: :request do
  let(:user) { create(:user, username: "builder") }
  let!(:tool) { create(:github_repo, user: user, name: "app", full_name: "builder/app", description: "A tool.") }
  let!(:bare) { create(:github_repo, user: user, name: "bare", full_name: "builder/bare", url: "https://github.com/builder/bare") }
  let!(:idle) { create(:github_repo, user: user, name: "idle", full_name: "builder/idle") }

  before do
    3.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) }
    create(:entry, user: user, repo_name: "builder/bare", occurred_at: 2.days.ago)
    sign_in_as(user)
  end

  def page
    Nokogiri::HTML(response.body)
  end

  def project_rows
    page.css("[data-chart-table] [data-chart-row]").to_h { |row| [ row["data-chart-row"], row.text.squish ] }
  end

  def page_switch(repo)
    page.at_css("[data-chart-row='#{repo}'] form[action^='/github_repos/'] button[role='switch']")
  end

  it "charts the last 30 days of the builder's work with no figure over it, and keeps the entry filters on its links" do
    get "/dashboard", params: { q: "work" }

    activity = page.at_css("section[aria-labelledby='your-activity']")
    expect(activity.at_css("[aria-label='Numbers on the chart']").text.squish).to eq("Commits 4")
    expect(activity.css(".os-num.leading-none, .os-big")).to be_empty
    expect(activity.at_css("svg[role='img']")["aria-label"]).to eq("7-day average of commits per day by project, last 30 days")
    quarter = activity.css("[aria-label='Time range'] a").find { |a| a.text == "90 days" }
    expect(quarter["href"]).to eq("/dashboard?q=work&range=90d")
    only = activity.at_css("[data-chart-row='builder/bare'] a[aria-label='Show only bare']")
    expect(only["href"]).to eq("/dashboard?projects=builder%2Fbare&q=work")
    expect(activity.text.squish).not_to include("The switches set what visitors see")
  end

  it "draws each switch for what visitors see as an eye, saying in its title what it does on the stage" do
    create(:entry, user: user, repo_name: "builder/idle", occurred_at: 1.day.ago)
    idle.update!(included: false)
    get "/dashboard"

    eyes = page.css("[data-chart-table] button[role='switch']:not(.os-pin)")
    expect(eyes.map { |eye| eye["class"] }.uniq).to eq([ "os-eye" ])
    expect(eyes.map { |eye| eye.css("svg").map { |svg| svg["class"].split.first } }.uniq).to eq([ %w[os-eye-open os-eye-shut] ])
    expect(page_switch("builder/app")["title"]).to eq("Visitors see it on your stage. Click to hide it.")
    expect([ page_switch("builder/idle")["aria-checked"], page_switch("builder/idle")["title"] ]).to eq([ "false", "Only you see it. Click to show it on your stage." ])
    expect(page.at_css("section[aria-labelledby='your-activity']").text.squish).not_to include("Visitors see it on your stage")
  end

  it "marks what shipped on the chart, each a link to the entries opened on it" do
    milestone = create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", title: "Launched", occurred_at: 1.day.ago)

    get "/dashboard", params: { range: "90d" }

    link = page.at_css("section[aria-labelledby='your-activity'] .os-chart a[aria-label^='Milestone: Launched']")
    expect(link["href"]).to eq("/dashboard?entry=#{milestone.id}&range=90d#entry-#{milestone.id}")
    marks = JSON.parse(page.at_css("#activity-chart-props").text)["initial"]["chart"]["marks"]
    expect(marks.map { |mark| [ mark["key"], mark["badge"], mark["entries"].pluck("id") ] }).to eq([ [ "builder/app", "milestone", [ milestone.id ] ] ])
  end

  it "opens the entries on the one a mark names, past the newer ones, with a way back to the newest" do
    older = create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", title: "Old launch", occurred_at: 20.days.ago)
    30.times { |i| create(:entry, user: user, repo_name: "builder/app", title: "Newer #{i}", occurred_at: (i + 1).hours.ago) }

    get "/dashboard", params: { entry: older.id }

    rows = page.css("#entries-list-timeline [id^='entry-']")
    expect(rows.first["id"]).to eq("entry-#{older.id}")
    back = page.css("[data-tabs-panel='timeline'] a").find { |a| a.text.squish == "Back to the newest" }
    expect(back["href"]).to eq("/dashboard?tab=timeline#entries")

    get "/dashboard", params: { entry: older.id }, headers: { "Turbo-Frame" => "entries-lists" }
    expect(Nokogiri::HTML(response.body).css("#entries-list-timeline [id^='entry-']").first["id"]).to eq("entry-#{older.id}")

    get "/dashboard"
    expect(page.css("#entries-list-timeline [id^='entry-']").map { |row| row["id"] }).not_to include("entry-#{older.id}")
    expect(page.css("a").map { |a| a.text.squish }).not_to include("Back to the newest")
  end

  it "lists every repo with work under the chart, each with Edit, and leaves out repos with none" do
    get "/dashboard"

    expect(project_rows.keys).to eq(%w[builder/app builder/bare])
    expect(project_rows["builder/app"]).to start_with("app Only Edit")
    expect(page.at_css("[data-chart-row='builder/bare'] a.os-btn2")["href"]).to eq("/projects/#{bare.id}/edit")
    expect(page.at_css("section[aria-labelledby='your-projects']")).to be_nil
    expect(page.at_css("section[aria-labelledby='your-activity'] [data-sync-status]")).to be_present
    expect(idle).to be_persisted
  end

  it "wraps a long project name rather than cutting it short, so it can be read in full" do
    get "/dashboard"

    expect(page.css("[data-chart-row] th span.font-bold").map { |name| name["class"].split.first }).to eq(%w[wrap-anywhere wrap-anywhere])
  end

  it "hides a project from the page with its switch, and keeps it listed to switch back" do
    get "/dashboard"
    expect(page_switch("builder/app")["aria-checked"]).to eq("true")

    patch "/github_repos/#{tool.id}", params: { included: "false" }
    expect(response).to redirect_to("/dashboard#activity")

    get "/dashboard"
    expect(project_rows.keys.last).to eq("builder/app")
    expect(page_switch("builder/app")["aria-checked"]).to eq("false")
    expect(page.css("[data-chart-row='builder/app'] td").map { |cell| cell.text.squish }.last(2)).to eq([ "Commits –", "Site visits –" ])
    expect(page.at_css("[data-chart-row='builder/app'] th a[href*='projects=']")).to be_nil
    expect(user.entries.where(repo_name: "builder/app").pluck(:hidden).uniq).to eq([ true ])
  end

  describe "the table under Your activity" do
    before do
      tool.update!(homepage: "https://app.example", site_source: "script", site_set_up_at: 3.days.ago, site_first_visit_at: 2.days.ago)
      tool.site_visit_days.create!(day: 1.day.ago.to_date, visits: 90, visitors: 30)
    end

    # The island's first view of a row's site visits cell, or another's.
    def island_cell(repo, key = "visits")
      props = JSON.parse(page.at_css("#activity-chart-props").text)
      props["initial"]["table"]["rows"].find { |row| row["key"] == repo }["cells"].find { |cell| cell["key"] == key }
    end

    def cells(repo)
      page.css("[data-chart-row='#{repo}'] td").drop(1).map do |cell|
        [ cell.text.squish.sub(/\A(Commits|Site visits|Site visitors) ?/, ""), cell.at_css("button[role='switch']")&.[]("aria-checked") ]
      end
    end

    def drawn
      page.css("section[aria-labelledby='your-activity'] svg[role='img'] path").map { |path| path["data-number"] }
    end

    # The chart's tooltip, from the island's first view: its columns, and
    # each project's values at today's point in their order.
    def tooltip
      chart = JSON.parse(page.at_css("#activity-chart-props").text)["initial"]["chart"]
      [ chart["tips"].pluck("key"), chart["columns"].last["rows"].to_h { |row| [ row["name"], row["values"] ] } ]
    end

    it "lists each project with its commits, site visits and site visitors, each shown to visitors, and offers to set up visits where none count" do
      get "/dashboard"

      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90", "true" ], [ "30", "true" ] ])
      expect(cells("builder/bare")).to eq([ [ "1", "true" ], [ "Set up", nil ], [ "–", nil ] ])
      expect(page.css("[data-chart-table] thead th").map { |head| head.text.squish }).to eq([ "Projects", "Your stage", "Commits", "Site visits", "Site visitors" ])
      expect(page.at_css("[data-chart-row='builder/bare'] a[aria-label^='Set up']")["href"]).to eq("/projects/#{bare.id}/edit?site=open#site-visits")
      activity = page.at_css("section[aria-labelledby='your-activity']").text.squish
      expect(activity).to include("Site visits 90")
      expect(drawn).to contain_exactly("commits", "commits", "visits")
    end

    it "hides a number from visitors for one project: its value stays, grey, and the chart leaves its line out" do
      patch "/projects/#{tool.id}/numbers", params: { number: "visits", shown: "false", range: "30d" }
      expect(response).to redirect_to(dashboard_path(range: "30d", anchor: "your-activity"))
      expect(tool.reload.hidden_numbers).to eq([ "visits" ])

      get "/dashboard"
      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90", "false" ], [ "30", nil ] ])
      expect(page.at_css("[data-chart-row='builder/app'] td:nth-last-child(2) .os-num")["class"]).to include("text-ink-3", "font-medium")
      expect(drawn).to eq(%w[commits commits])

      patch "/projects/#{tool.id}/numbers", params: { number: "visits", shown: true }, as: :json
      expect(response).to have_http_status(:no_content)
      expect(tool.reload.hidden_numbers).to eq([])
    end

    it "says Paused where Free counts another project, its value grey and no switch, and leaves its line off the chart" do
      bare.update!(homepage: "https://bare.example", site_source: "script", site_set_up_at: 10.days.ago)
      get "/dashboard"

      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90 Paused", nil ], [ "30", nil ] ])
      paused = page.at_css("[data-chart-row='builder/app'] td:nth-last-child(2)")
      expect(paused.at_css(".os-num")["class"]).to include("text-ink-3")
      expect(paused.at_css("a").attributes.transform_values(&:value)).to include("href" => "/projects/#{tool.id}/edit?site=open#site-visits",
                                                                                  "aria-label" => "Paused: see why app's site visits do not count")
      expect(island_cell("builder/app")).to include("value" => "90", "pick" => nil)
      expect(island_cell("builder/app")["link"]).to eq("text" => "Paused", "label" => "Paused: see why app's site visits do not count",
                                                       "path" => "/projects/#{tool.id}/edit?site=open#site-visits")
      expect(cells("builder/bare")).to eq([ [ "1", "true" ], [ "Set up", nil ], [ "–", nil ] ])
      expect(drawn).to eq(%w[commits commits])
    end

    it "says Set up where the script is off, beside the value in grey while the window has any" do
      tool.update!(site_source: nil)
      get "/dashboard"
      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90 Set up", nil ], [ "30", nil ] ])
      expect(island_cell("builder/app")).to include("value" => "90", "pick" => nil)
      expect(island_cell("builder/app")["link"]).to eq("text" => "Set up", "label" => "Set up app's site visits", "path" => "/projects/#{tool.id}/edit?site=open#site-visits")

      tool.site_visit_days.update_all(day: 60.days.ago.to_date)
      get "/dashboard", params: { range: "30d" }
      expect(cells("builder/app").last(2)).to eq([ [ "Set up", nil ], [ "0", nil ] ])
    end

    it "switches site visitors off for one project and on again, in the tooltip beside its site visits, leaving those and the other projects alone" do
      switch = -> { page.at_css("[data-chart-row='builder/app'] button[role='switch'][aria-label='Show site visitors for app']") }
      get "/dashboard", params: { show: "site_visitors" }
      expect(switch.call["aria-checked"]).to eq("true")
      expect(drawn).to contain_exactly("commits", "commits", "visits")
      expect(tooltip).to eq([ %w[commits visits site_visitors], { "app" => %w[0.4 12.9 4.3], "bare" => %w[0.1 – –] } ])

      patch "/projects/#{tool.id}/numbers", params: { number: "site_visitors", shown: "false", show: "site_visitors" }
      expect(response).to redirect_to(dashboard_path(show: "site_visitors", anchor: "your-activity"))
      expect(tool.reload.hidden_numbers).to eq([ "site_visitors" ])

      get "/dashboard", params: { show: "site_visitors" }
      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90", "true" ], [ "30", "false" ] ])
      expect(drawn).to contain_exactly("commits", "commits", "visits")
      expect(tooltip).to eq([ %w[commits visits], { "app" => %w[0.4 12.9], "bare" => %w[0.1 –] } ])

      patch "/projects/#{tool.id}/numbers", params: { number: "site_visitors", shown: "true" }, as: :json
      expect(response).to have_http_status(:no_content)
      expect(tool.reload.hidden_numbers).to eq([])
    end

    it "lists the site visitors of a project that hides its site visits in grey with no switch, the site visits keeping theirs, and their own switch back with those" do
      tool.update!(hidden_numbers: %w[visits site_visitors])
      get "/dashboard"

      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90", "false" ], [ "30", nil ] ])
      expect(page.at_css("[data-chart-row='builder/app'] td:last-child .os-num")["class"]).to include("text-ink-3", "font-medium")
      expect(island_cell("builder/app", "site_visitors")).to include("value" => "30", "shown" => false, "pick" => nil, "link" => nil)
      expect(island_cell("builder/app")).to include("value" => "90", "shown" => false, "pick" => false, "link" => nil)
      expect(tooltip).to eq([ %w[commits], { "app" => %w[0.4], "bare" => %w[0.1] } ])

      patch "/projects/#{tool.id}/numbers", params: { number: "visits", shown: "true" }, as: :json
      expect(tool.reload.hidden_numbers).to eq([ "site_visitors" ])
      get "/dashboard"
      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90", "true" ], [ "30", "false" ] ])
    end

    # The island's switches note a pending switch by the table's row and cell
    # keys, and blank a tooltip value by its row's key and its tip's.
    it "keys the tooltip's rows and tips as the table keys its rows and cells, so a switch blanks its own value" do
      get "/dashboard"
      view = JSON.parse(page.at_css("#activity-chart-props").text)["initial"]
      cells = view["table"]["rows"].to_h { |row| [ row["key"], row["cells"].pluck("key") ] }
      rows = view["chart"]["columns"].last["rows"].pluck("key")

      expect([ rows, view["chart"]["tips"].pluck("key") ]).to eq([ %w[builder/app builder/bare], %w[commits visits site_visitors] ])
      expect(rows.map { |key| cells.fetch(key) }).to all(include(*view["chart"]["tips"].pluck("key")))
    end

    it "refuses a number a project cannot hide, a switch with no state, and someone else's project" do
      patch "/projects/#{tool.id}/numbers", params: { number: "views", shown: false }, as: :json
      expect(response).to have_http_status(:unprocessable_entity)
      patch "/projects/#{tool.id}/numbers", params: { number: "visits" }
      expect(response).to redirect_to(dashboard_path(anchor: "your-activity"))
      expect(flash[:alert]).to eq("That number cannot be switched.")
      expect(tool.reload.hidden_numbers).to eq([])

      theirs = create(:github_repo, user: create(:user))
      patch "/projects/#{theirs.id}/numbers", params: { number: "visits", shown: "false" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "pinning a project to the stage" do
    # In the chart's table or the list under it.
    def pin_switch(name)
      page.at_css("form[action$='/pin'] button[role='switch'][aria-label='Pin #{name} to your stage']")
    end

    def stage_cards
      get "/builder"
      page.css("section[aria-labelledby='projects'] .os-card .os-h3").map { |name| name.text.squish }
    end

    it "shows the projects with a colour pinned, and unpinning one leaves the others pinned" do
      get "/dashboard"
      expect(%w[aria-checked aria-label class].map { |name| pin_switch("app")[name] }).to eq([ "true", "Pin app to your stage", "os-eye os-pin" ])
      expect(pin_switch("bare")["title"]).to eq("Pinned: it has a colour and a card on your stage. Click to unpin it.")

      patch "/projects/#{bare.id}/pin", params: { pinned: "false", range: "90d" }

      expect(response).to redirect_to("/dashboard?range=90d#your-activity")
      expect(stage_cards).to eq(%w[app])
      get "/dashboard"
      expect([ pin_switch("app")["aria-checked"], pin_switch("bare")["aria-checked"], pin_switch("bare")["title"] ])
        .to eq([ "true", "false", "Pin it to give it a colour and a card on your stage." ])

      patch "/projects/#{bare.id}/pin", params: { pinned: "true" }
      expect(stage_cards).to eq(%w[app bare])
    end

    it "refuses an eleventh pin with a message at the top of the page, swapping none out, and offers no pin for a hidden project" do
      create(:entry, user: user, repo_name: "builder/idle", occurred_at: 1.day.ago)
      idle.update!(included: false)
      10.times { |i| 5.times { create(:entry, user: user, repo_name: "builder/top#{i}") } }
      get "/dashboard"

      expect(pin_switch("idle")).to be_nil
      expect(%w[aria-checked title].map { |name| pin_switch("app")[name] }).to eq([ "false", "10 projects are pinned. Unpin one to pin this one." ])

      patch "/projects/#{tool.id}/pin", params: { pinned: "true" }

      expect(response).to redirect_to("/dashboard")
      expect(flash[:alert]).to eq("You can pin 10 projects at a time. Unpin one first.")
      expect(stage_cards).to eq((0..9).map { |i| "top#{i}" })
    end

    it "pins one from the list under the table, and comes back to the list on its view" do
      tops = Array.new(10) { |i| create(:github_repo, user: user, name: "top#{i}", full_name: "builder/top#{i}") }
      tops.each { |top| 5.times { create(:entry, user: user, repo_name: top.full_name) } }

      patch "/projects/#{tops.last.id}/pin", params: { pinned: "false" }
      patch "/projects/#{bare.id}/pin", params: { pinned: "true", back: "list", list_sort: "name", range: "90d" }

      expect(response).to redirect_to("/dashboard?list_sort=name&range=90d#more-projects")
      expect(stage_cards).to eq([ *(0..8).map { |i| "top#{i}" }, "bare" ])
    end

    it "pins no other builder's project" do
      theirs = create(:github_repo, user: create(:user), full_name: "someone/tool")

      patch "/projects/#{theirs.id}/pin", params: { pinned: "true" }

      expect(response).to have_http_status(:not_found)
      expect(theirs.reload.pinned).to be(false)
    end
  end

  describe "a builder with more projects than colours" do
    before { 10.times { |i| 5.times { create(:entry, user: user, repo_name: "builder/top#{i}", occurred_at: 1.day.ago) } } }

    def list
      page.at_css("#more-projects")
    end

    def listed
      list.css("a[data-turbo-frame='_top']").map(&:text)
    end

    it "gives the table the ten with a colour, and lists the rest right under it, with no link to it, with Edit and their stage switches" do
      get "/dashboard", params: { range: "90d" }

      expect(project_rows.keys).to eq((0..9).map { |i| "builder/top#{i}" })
      expect(page.at_css("[data-chart-table] a[href='#more-projects']")).to be_nil
      expect(list.at_css("h3").text).to eq("2 more projects")
      expect(listed).to eq(%w[app bare])
      expect(list.at_css("a[aria-label='Edit app']")["href"]).to eq("/projects/#{tool.id}/edit")
      expect(page.at_css("script#project-list-props").text).to include("/api/projects/builder?dashboard=1")
      eye = list.at_css("form[action='/github_repos/#{tool.id}']")
      expect(eye.css("input[type='hidden']").to_h { |field| [ field["name"], field["value"] ] }).to include("included" => "false", "back" => "list", "range" => "90d")
      expect(list.at_css("button[aria-label='Pin app to your stage']")["title"]).to eq("10 projects are pinned. Unpin one to pin this one.")
    end

    it "finds, sorts and pages the list on its own params, as the entries read q" do
      get "/dashboard", params: { list_q: "bar", q: "work" }
      expect(listed).to eq(%w[bare])
      expect(list.at_css("input[name='list_q']")["value"]).to eq("bar")

      get "/dashboard", params: { list_sort: "name" }
      by_commits = list.css(".os-pills a").find { |link| link.text == "Most commits" }
      expect(by_commits["href"]).to eq("/dashboard?list_sort=commits#more-projects")
    end

    it "comes back to the list on its view once a project is hidden from it" do
      patch "/github_repos/#{bare.id}", params: { included: "false", back: "list", list_q: "ba" }

      expect(response).to redirect_to("/dashboard?list_q=ba#more-projects")
      get "/dashboard"
      expect(listed).to eq(%w[app])
    end
  end
end
