require "rails_helper"

RSpec.describe "Project pages", type: :request do
  let(:user) { create(:user, username: "builder", display_name: "Bea") }

  before do
    create(:github_repo, user: user, full_name: "builder/side.app", name: "side.app", description: "A small app.", homepage: "https://side.example")
    create(:entry, user: user, repo_name: "builder/side.app", title: "Ship the form")
    create(:entry, user: user, repo_name: "builder/other", title: "Other work")
    create(:entry, user: user, repo_name: "builder/side.app", entry_type: "milestone", source: "manual", title: "Launched it", body: "In my words.")
  end

  it "shows the project: what it is, its commits, what's new and the other projects" do
    get "/builder/side.app"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("A small app.", "Visit side.example", "Ship the form", "Launched it", "In my words.")
    expect(response.body).to include(%(href="/builder/other"))
    expect(response.body).not_to include("Other work")
  end

  it "names the other builders whose pages show the same repo, busiest first, each linked to their page for it" do
    ada = create(:user, username: "ada")
    2.times { |i| create(:entry, user: ada, repo_name: "builder/side.app", title: "Ada's work #{i}") }
    cy = create(:user, username: "cy")
    create(:entry, user: cy, repo_name: "builder/side.app", title: "Cy's work")
    create(:entry, user: create(:user, username: "gone", deleted_at: 1.day.ago), repo_name: "builder/side.app")
    create(:entry, user: create(:user, username: "quiet"), repo_name: "builder/side.app", visibility: :private_entry)

    get "/builder/side.app"

    rows = Nokogiri::HTML(response.body).xpath("//h2[text()='Also building this']/following-sibling::ul[1]//a")
    expect(rows.map { |row| [ row.text.squish, row["href"] ] }).to eq([ [ "@ada 2 commits", "/ada/side.app" ], [ "@cy 1 commit", "/cy/side.app" ] ])
  end

  it "shows the project's picture beside what it is" do
    user.github_repos.find_by(full_name: "builder/side.app").update!(image_edit: "https://side.example/cover.png")

    get "/builder/side.app"

    header = Nokogiri::HTML(response.body).at_css("section[aria-label='side.app']")
    expect(header.at_css("img[src='https://side.example/cover.png']")).to be_present
  end

  it "shares the project's picture as the link's preview, its card without one" do
    preview = -> { Nokogiri::HTML(response.body).css("meta[property='og:image'], meta[name='twitter:image']").map { |meta| meta["content"] } }

    get "/builder/side.app"
    expect(preview.call).to eq([ "http://www.example.com/og/builder/side.app?v=#{SeoHelper::SHARE_CARD_VERSION}" ] * 2)

    user.github_repos.find_by(full_name: "builder/side.app").update!(image_edit: "https://side.example/cover.png")
    get "/builder/side.app"
    expect(preview.call).to eq([ "https://side.example/cover.png" ] * 2)
  end

  it "finds the project whatever the case of its name" do
    get "/builder/SIDE.APP"

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(%(rel="canonical" href="http://www.example.com/builder/side.app"))
  end

  it "opens on another window from the pills, with no figure over the chart" do
    get "/builder/side.app", params: { range: "30d" }

    page = Nokogiri::HTML(response.body)
    expect(page.at_css("[aria-label='Time range'][role='group'] a[aria-current='page']").text).to eq("30 days")
    expect(page.at_css("[data-react='progress'] svg[role='img']")["aria-label"]).to eq("7-day average of commits per day by project, last 30 days")
    expect(page.css("[data-react='progress'] .os-big, [data-chart-table]")).to be_empty
  end

  describe "a project the builder hid" do
    # As the dashboard's switch hides it: the repo, and its synced entries.
    before do
      user.github_repos.find_by(full_name: "builder/side.app").update!(included: false)
      user.entries.where(repo_name: "builder/side.app", source: "github").update_all(hidden: true)
    end

    it "is gone for visitors, with what was logged on it, from its page and the builder's" do
      get "/builder/side.app"
      expect(response).to redirect_to("/builder")

      get "/builder"
      expect(response.body).not_to include("side.app", "Launched it")
    end

    it "opens for the builder alone, as it would show, saying only they see it" do
      sign_in_as(user)
      get "/builder/side.app"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Only you can see this page", "Ship the form", "Launched it")
      expect(Nokogiri::HTML(response.body).at_css("a:contains('Show it again on the dashboard')")["href"]).to eq("/dashboard#activity")
      expect(user.project_views.count).to eq(0)
    end

    it "answers the chart's other windows for the builder alone, and never into a shared cache" do
      params = { range: "30d", project: "builder/side.app", reveal: "builder/side.app" }
      get "/api/progress/builder", params: params
      expect(response.parsed_body["numbers"]).to eq([])
      expect(response.headers["Cache-Control"]).to include("private")

      sign_in_as(user)
      get "/api/progress/builder", params: params
      expect(response.parsed_body["numbers"].map { |number| number["value"] }).to eq([ "1" ])
      expect(response.headers["Cache-Control"]).to include("private")
    end
  end

  it "sends a name that is no project back to the builder's page" do
    get "/builder/nope"

    expect(response).to redirect_to("/builder")
  end

  it "answers 404 for a builder who does not exist" do
    get "/nobody/side.app"

    expect(response).to have_http_status(:not_found)
  end

  describe "visits" do
    let(:browser) { { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15", "HTTP_REFERER" => "https://news.ycombinator.com/item?id=1" } }

    it "counts a visitor's, by the project's repo, with where they came from" do
      expect { get "/builder/side.app", headers: browser }.to change(user.project_views, :count).by(1)

      expect(user.project_views.last).to have_attributes(repo_name: "builder/side.app", referrer: "news.ycombinator.com")
      expect(user.profile_views.count).to eq(0)
    end

    it "never counts the builder's own visit" do
      sign_in_as(user)
      get "/builder/side.app", headers: browser

      expect(user.project_views.count).to eq(0)
    end

    it "never counts a bot's visit" do
      get "/builder/side.app", headers: { "HTTP_USER_AGENT" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }

      expect(user.project_views.count).to eq(0)
    end
  end

  describe "site visits" do
    let(:repo) { user.github_repos.find_by!(name: "side.app") }

    before do
      repo.update!(site_source: "script", site_token: "os_a", site_first_visit_at: 3.days.ago)
      repo.site_visit_days.create!(day: Date.current, visits: 1204, visitors: 800)
      user.update!(pro: true)
    end

    def toggles
      Nokogiri::HTML(response.body).css("[aria-label='Numbers on the chart'] > *").map { |toggle| [ toggle.text.squish, toggle["aria-current"] == "true" ] }
    end

    it "puts a toggle per number above the chart, both drawn, the chart comparing them" do
      get "/builder/side.app"
      expect(toggles).to eq([ [ "Commits 1", true ], [ "Site visits 1,204", true ] ])
      expect(response.body).to include("Commits solid and site visits dotted, each against its own peak in the window")

      get "/builder/side.app", params: { show: "visits", range: "30d" }
      page = Nokogiri::HTML(response.body)
      expect(toggles).to eq([ [ "+ Commits 1", false ], [ "Site visits 1,204", true ] ])
      expect(page.css(".os-big")).to be_empty
      expect(response.body).to include("A 7-day average of site visits per day.")
      props = JSON.parse(page.at_css("#progress-props").text)
      expect(props).to include("mode" => "project", "endpoint" => "/api/progress/builder?project=builder%2Fside.app")
      expect(props["initial"]).to include("drawn" => [ "visits" ], "defaultShow" => %w[commits visits])
    end

    it "lets the builder hide its commits from visitors, which leaves site visits alone on the chart" do
      repo.update!(hidden_numbers: [ "commits" ])
      get "/builder/side.app"

      expect(toggles).to eq([ [ "Site visits 1,204", true ] ])
    end

    it "keeps them off the page while switched off, or before Pro on a second site" do
      repo.update!(hidden_numbers: [ "visits" ])
      get "/builder/side.app"
      expect(toggles).to eq([ [ "Commits 1", true ] ])

      repo.update!(hidden_numbers: [])
      user.update!(pro: false)
      other = create(:github_repo, user: user, site_source: "script")
      other.site_visit_days.create!(day: Date.current, visits: 5000, visitors: 10)
      get "/builder/side.app"
      expect(toggles).to eq([ [ "Commits 1", true ] ])
    end

    it "shows them on the builder's page too, beside every project's commits" do
      get "/builder"

      expect(toggles).to eq([ [ "Commits 2", true ], [ "Site visits 1,204", true ] ])
      row = Nokogiri::HTML(response.body).at_css("[data-chart-row='builder/side.app']")
      expect(row.css("td").map { |cell| cell.text.squish }).to eq([ "Commits 1", "Site visits 1,204" ])
    end
  end

  it "is linked from the builder's page and listed in the sitemap" do
    get "/builder"
    expect(response.body).to include(%(href="/builder/side.app"))

    get "/sitemap.xml"
    expect(response.body).to include("http://www.example.com/builder/side.app")
  end
end
