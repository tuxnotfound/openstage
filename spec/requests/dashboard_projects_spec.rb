require "rails_helper"

# The dashboard's Projects tab (DASHBOARD_TABS_PLAN.md, Stage 2): a list, a
# project and its one switch a row, no number; a click brings a project's
# numbers in, a line each, read for that one project.
RSpec.describe "The dashboard's Projects tab", type: :request do
  let(:user) { create(:user, username: "builder", github_username: "builder") }
  let!(:tool) { create(:github_repo, user: user, name: "app", full_name: "builder/app", homepage: "https://app.example") }
  let!(:bare) { create(:github_repo, user: user, name: "bare", full_name: "builder/bare") }
  let!(:idle) { create(:github_repo, user: user, name: "idle", full_name: "builder/idle") }

  before do
    3.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) }
    create(:entry, user: user, repo_name: "builder/bare", occurred_at: 2.days.ago)
    sign_in_as(user)
  end

  def props
    JSON.parse(Nokogiri::HTML(response.body).at_css("#dashboard-projects-props").text)
  end

  def lines(repo)
    get "/api/dashboard/projects/#{repo.id}"
    response.parsed_body["lines"].to_h { |line| [ line["key"], [ line["state"], line["control"].except("aria", "path", "number") ] ] }
  end

  def line(repo, key)
    get "/api/dashboard/projects/#{repo.id}"
    response.parsed_body["lines"].find { |each| each["key"] == key }
  end

  def more_projects(count)
    count.times do |i|
      repo = create(:github_repo, user: user, name: "top#{i}", full_name: "builder/top#{i}")
      create(:entry, user: user, repo_name: repo.full_name, occurred_at: 1.day.ago)
    end
  end

  describe "the list" do
    it "lists every project with work, in the stage's order, the hidden ones last, each with its colour and its switch, and no number" do
      bare.update!(included: false)

      get "/dashboard"

      list = props["initial"]
      expect(list["rows"].map { |row| row.values_at("name", "colorClass", "stage") }).to eq([ [ "app", "os-project-1", true ], [ "bare", nil, false ] ])
      expect(list["rows"].first).to eq("id" => tool.id, "name" => "app", "colorClass" => "os-project-1", "pinned" => true, "stage" => true,
                                       "switch" => "/github_repos/#{tool.id}")
      expect(list.values_at("many", "views", "range", "empty", "count")).to eq([ false, [], nil, nil, 2 ])
      expect(props.values_at("open", "row", "endpoint")).to eq([ nil, nil, "/api/dashboard/projects" ])
    end

    it "opens on the pinned ones past ten projects, with All and Hidden, 25 rows a page, and finds a project by name" do
      more_projects(30)
      bare.update!(included: false)

      get "/dashboard"
      list = props["initial"]
      expect(list.values_at("many", "view", "pages")).to eq([ true, "pinned", 1 ])
      expect(list["views"]).to eq([ { "key" => "pinned", "label" => "Pinned", "count" => "10" }, { "key" => "all", "label" => "All", "count" => "32" },
                                    { "key" => "hidden", "label" => "Hidden", "count" => "1" } ])
      expect(list["rows"].size).to eq(10)

      get "/api/dashboard/projects", params: { view: "all", page: 2 }
      expect(response.parsed_body.values_at("view", "page", "pages", "range")).to eq([ "all", 2, 2, "26–32 of 32" ])
      expect(response.parsed_body["rows"].last["name"]).to eq("bare")

      get "/api/dashboard/projects", params: { view: "all", q: "TOP2" }
      expect(response.parsed_body["rows"].map { |row| row["name"] }).to match_array(%w[top2 top20 top21 top22 top23 top24 top25 top26 top27 top28 top29])

      get "/api/dashboard/projects", params: { view: "hidden", q: "zzz" }
      expect(response.parsed_body.values_at("rows", "empty")).to eq([ [], 'No hidden project named "zzz".' ])
    end

    it "lands on a project's row, in the view and on the page that hold it" do
      more_projects(30)
      bare.update!(included: false)

      get "/dashboard", params: { row: bare.id }

      expect(props["initial"].values_at("view", "page")).to eq([ "hidden", 1 ])
      expect(props["row"]).to eq(bare.id)
    end

    it "answers no one signed out, and nobody about another builder's project" do
      delete "/sign_out"
      get "/api/dashboard/projects"
      expect(response).to have_http_status(:unauthorized)

      sign_in_as(user)
      get "/api/dashboard/projects/#{create(:github_repo).id}"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "a project's numbers" do
    it "reads, before anything is set up, its commits' switch and the steps that set site visits and MRR up, the first one filled" do
      get "/api/dashboard/projects/#{tool.id}"

      expect(response.parsed_body.slice("id", "name", "colorClass", "page", "edit"))
        .to eq("id" => tool.id, "name" => "app", "colorClass" => "os-project-1", "page" => "/builder/app", "edit" => "/projects/#{tool.id}/edit")
      expect(response.parsed_body["lines"].map { |line| [ line["name"], line["state"], line["control"]["kind"], line["control"]["label"] ] })
        .to eq([ [ "Commits", "From GitHub", "switch", nil ], [ "Site visits", "Not counted yet", "link", "Set up site visits" ],
                 [ "MRR", "Not counted yet", "link", "Set up MRR" ] ])
      expect(line(tool, "visits")["control"]).to include("path" => "/dashboard/site-visits?project=#{tool.id}", "filled" => true,
                                                        "aria" => "Set up site visits for app")
      expect(line(tool, "mrr")["control"]).to include("path" => settings_path(tab: "integrations", project: tool.id, anchor: "revenue"), "filled" => false)
      expect(line(tool, "commits")["control"]).to include("on" => true, "dead" => false, "path" => "/projects/#{tool.id}/numbers",
                                                         "number" => "commits", "aria" => "Show Commits for app")
    end

    it "says the line waits for its first visit, then counts it with site visitors beside, dead while site visits are hidden" do
      tool.update!(site_source: "script", site_token: "os_a", site_set_up_at: 1.hour.ago)
      expect(line(tool, "visits")["state"]).to eq("No visit from app.example yet")
      expect(line(tool, "visits")["control"]).to include("label" => "Continue setup", "path" => "/dashboard/site-visits?project=#{tool.id}", "filled" => true)

      tool.update!(site_first_visit_at: 1.minute.ago, hidden_numbers: [ "visits" ])
      expect(lines(tool).slice("visits", "site_visitors")).to eq(
        "visits" => [ "From app.example", { "kind" => "switch", "on" => false, "dead" => false, "filled" => false } ],
        "site_visitors" => [ "From app.example", { "kind" => "switch", "on" => true, "dead" => true, "filled" => false } ]
      )
      expect(line(tool, "mrr")["control"]["filled"]).to be(true)
    end

    it "offers Go Pro where Free counts another project's site visits or MRR" do
      account = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok")
      account.revenue_products.create!(external_id: "prod_a", name: "A", github_repo: bare)
      bare.update!(site_set_up_at: 1.day.ago, revenue_set_up_at: 1.day.ago)

      expect(lines(tool).slice("visits", "mrr")).to eq(
        "visits" => [ "Free counts site visits for one project", { "kind" => "link", "label" => "Go Pro", "filled" => false } ],
        "mrr" => [ "Free counts MRR for one project", { "kind" => "link", "label" => "Go Pro", "filled" => false } ]
      )
      expect(line(tool, "visits")["control"]).to include("path" => "/pricing", "aria" => "Go Pro to set up site visits for app")
    end

    it "sets MRR up on Settings until Stripe takes a key, then on the project's own view with its products open" do
      expect(line(tool, "mrr")["control"]["path"]).to eq(settings_path(tab: "integrations", project: tool.id, anchor: "revenue"))

      user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok")
      expect(line(tool, "mrr")["control"]["path"]).to eq("/projects/#{tool.id}/edit?revenue=open#revenue")
    end

    it "reads MRR and paying customers from Stripe with their switches on Pro, and with Pro's mark on Free, where only the builder sees them" do
      account = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok")
      account.revenue_products.create!(external_id: "prod_a", name: "A", github_repo: tool)

      expect(lines(tool).slice("mrr", "customers")).to eq(
        "mrr" => [ "From Stripe. On Free only you see it.", { "kind" => "pro", "filled" => false } ],
        "customers" => [ "From Stripe. On Free only you see it.", { "kind" => "pro", "filled" => false } ]
      )

      user.update!(pro: true)
      expect(lines(tool).slice("mrr", "customers").transform_values(&:first)).to eq("mrr" => "From Stripe", "customers" => "From Stripe")
      expect(line(tool, "customers")["control"]).to include("kind" => "switch", "on" => true, "number" => "customers")
    end

    it "keeps the lines of a project off the stage, their switches dead" do
      tool.update!(included: false)

      expect(lines(tool)["commits"]).to eq([ "From GitHub", { "kind" => "switch", "on" => true, "dead" => true, "filled" => false } ])
    end

    it "pins a project past ten, and says why it cannot while every colour is taken" do
      more_projects(12)
      tops = user.github_repos.where("name LIKE 'top%'").order(:name).first(10)
      tops.each { |repo| repo.update!(pinned: true) }

      pin = line(bare, "pin")
      expect(pin.values_at("name", "state", "sep")).to eq([ "Pinned", "10 projects are pinned: unpin one first", true ])
      expect(pin["control"]).to include("kind" => "switch", "on" => false, "dead" => true, "path" => "/projects/#{bare.id}/pin",
                                        "aria" => "Pin bare on your stage")
      expect(line(tops.first, "pin")["state"]).to eq("A colour and a card on your stage")
    end

    it "opens a project's numbers from the address, the way back from Set up site visits" do
      get "/dashboard", params: { project: tool.id }

      expect(props["open"]).to include("id" => tool.id, "name" => "app")
      expect(props["open"]["lines"].map { |each| each["key"] }).to eq(%w[commits visits mrr])
    end
  end

  # The switches save through the paths they have today, answering the tab's
  # script in JSON, and land somewhere that exists without it.
  describe "the switches" do
    let(:json) { { "Accept" => "application/json", "Content-Type" => "application/json" } }

    it "takes a project off the stage and back, with its synced entries, and lands on its row without the script" do
      patch "/github_repos/#{tool.id}", params: { included: "false" }.to_json, headers: json
      expect(response).to have_http_status(:no_content)
      expect(tool.reload.included).to be(false)
      expect(user.entries.where(repo_name: "builder/app").pluck(:hidden).uniq).to eq([ true ])

      patch "/github_repos/#{tool.id}", params: { included: "true" }
      expect(response).to redirect_to(dashboard_path(row: tool.id))
      expect(tool.reload.included).to be(true)
    end

    it "shows or hides a number, and lands on the project's numbers without the script" do
      patch "/projects/#{tool.id}/numbers", params: { number: "commits", shown: false }.to_json, headers: json
      expect(response).to have_http_status(:no_content)
      expect(tool.reload.hidden_numbers).to eq([ "commits" ])

      patch "/projects/#{tool.id}/numbers", params: { number: "commits", shown: "true" }
      expect(response).to redirect_to(dashboard_path(project: tool.id))
    end

    it "pins a project, refuses an eleventh in its own words, and lands on its numbers without the script" do
      more_projects(12)
      user.github_repos.where("name LIKE 'top%'").order(:name).first(10).each { |repo| repo.update!(pinned: true) }

      patch "/projects/#{bare.id}/pin", params: { pinned: true }.to_json, headers: json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq("error" => "You can pin 10 projects at a time. Unpin one first.")

      patch "/projects/#{user.github_repos.find_by(name: 'top0').id}/pin", params: { pinned: false }.to_json, headers: json
      expect(response).to have_http_status(:no_content)

      patch "/projects/#{bare.id}/pin", params: { pinned: "true" }
      expect(response).to redirect_to(dashboard_path(project: bare.id))
      expect(bare.reload.pinned).to be(true)
    end

    it "sends a hidden project's own page back to its row" do
      tool.update!(included: false)

      get "/builder/app"

      link = Nokogiri::HTML(response.body).css("a").find { |each| each.text == "Show it again on the dashboard" }
      expect(link["href"]).to eq("/dashboard?row=#{tool.id}")
    end
  end
end
