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

  it "charts the last 90 days of the builder's work with no figure over it, and keeps the entry filters on its links" do
    get "/dashboard", params: { q: "work" }

    activity = page.at_css("section[aria-labelledby='your-activity']")
    expect(activity.at_css("[aria-label='Numbers on the chart']").text.squish).to eq("Commits 4")
    expect(activity.css(".os-num.leading-none, .os-big")).to be_empty
    expect(activity.at_css("svg[role='img']")["aria-label"]).to eq("Commits per week by project, last 90 days")
    month = activity.css("[aria-label='Time range'] a").find { |a| a.text == "30 days" }
    expect(month["href"]).to eq("/dashboard?q=work&range=30d")
    only = activity.at_css("[data-chart-row='builder/bare'] a[aria-label='Show only bare']")
    expect(only["href"]).to eq("/dashboard?projects=builder%2Fbare&q=work")
    expect(activity.css("p.os-note").map(&:text).grep(/The switches set what visitors see/).size).to eq(1)
    expect(activity.at_css("[data-react] p.os-note:contains('The switches set')")).to be_nil
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

    # The island's first view of a row's site visits cell.
    def island_cell(repo)
      props = JSON.parse(page.at_css("#activity-chart-props").text)
      props["initial"]["table"]["rows"].find { |row| row["key"] == repo }["cells"].find { |cell| cell["key"] == "visits" }
    end

    def cells(repo)
      page.css("[data-chart-row='#{repo}'] td").drop(1).map do |cell|
        [ cell.text.squish.sub(/\A(Commits|Site visits) ?/, ""), cell.at_css("button[role='switch']")&.[]("aria-checked") ]
      end
    end

    def drawn
      page.css("section[aria-labelledby='your-activity'] svg[role='img'] path").map { |path| path["data-number"] }
    end

    it "lists each project with its commits and site visits, each shown to visitors, and offers to set up visits where none count" do
      get "/dashboard"

      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90", "true" ] ])
      expect(cells("builder/bare")).to eq([ [ "1", "true" ], [ "Set up", nil ] ])
      expect(page.at_css("[data-chart-row='builder/bare'] a[aria-label^='Set up']")["href"]).to eq("/projects/#{bare.id}/edit?site=open#site-visits")
      activity = page.at_css("section[aria-labelledby='your-activity']").text.squish
      expect(activity).to include("Site visits 90", "and this chart follows them;", "Commits solid and site visits dotted")
      expect(drawn).to contain_exactly("commits", "commits", "visits")
    end

    it "hides a number from visitors for one project: its value stays, grey, and the chart leaves its line out" do
      patch "/projects/#{tool.id}/numbers", params: { number: "visits", shown: "false", range: "30d" }
      expect(response).to redirect_to(dashboard_path(range: "30d", anchor: "your-activity"))
      expect(tool.reload.hidden_numbers).to eq([ "visits" ])

      get "/dashboard"
      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90", "false" ] ])
      expect(page.at_css("[data-chart-row='builder/app'] td:last-child .os-num")["class"]).to include("text-ink-3", "font-medium")
      expect(drawn).to eq(%w[commits commits])

      patch "/projects/#{tool.id}/numbers", params: { number: "visits", shown: true }, as: :json
      expect(response).to have_http_status(:no_content)
      expect(tool.reload.hidden_numbers).to eq([])
    end

    it "says Paused where Free counts another project, its value grey and no switch, and leaves its line off the chart" do
      bare.update!(homepage: "https://bare.example", site_source: "script", site_set_up_at: 10.days.ago)
      get "/dashboard"

      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90 Paused", nil ] ])
      paused = page.at_css("[data-chart-row='builder/app'] td:last-child")
      expect(paused.at_css(".os-num")["class"]).to include("text-ink-3")
      expect(paused.at_css("a").attributes.transform_values(&:value)).to include("href" => "/projects/#{tool.id}/edit?site=open#site-visits",
                                                                                  "aria-label" => "Paused: see why app's site visits do not count")
      expect(island_cell("builder/app")).to include("value" => "90", "pick" => nil)
      expect(island_cell("builder/app")["link"]).to eq("text" => "Paused", "label" => "Paused: see why app's site visits do not count",
                                                       "path" => "/projects/#{tool.id}/edit?site=open#site-visits")
      expect(cells("builder/bare")).to eq([ [ "1", "true" ], [ "Set up", nil ] ])
      expect(drawn).to eq(%w[commits commits])
    end

    it "says Set up where the script is off, beside the value in grey while the window has any" do
      tool.update!(site_source: nil)
      get "/dashboard"
      expect(cells("builder/app")).to eq([ [ "3", "true" ], [ "90 Set up", nil ] ])
      expect(island_cell("builder/app")).to include("value" => "90", "pick" => nil)
      expect(island_cell("builder/app")["link"]).to eq("text" => "Set up", "label" => "Set up app's site visits", "path" => "/projects/#{tool.id}/edit?site=open#site-visits")

      tool.site_visit_days.update_all(day: 60.days.ago.to_date)
      get "/dashboard", params: { range: "30d" }
      expect(cells("builder/app").last).to eq([ "Set up", nil ])
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
end
