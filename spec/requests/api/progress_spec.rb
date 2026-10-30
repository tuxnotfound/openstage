require "rails_helper"

RSpec.describe "Api::Progress", type: :request do
  let(:user) { create(:user, username: "builder") }

  before do
    travel_to Time.utc(2026, 10, 24, 12)
    3.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) }
    create(:entry, user: user, repo_name: "builder/lib", occurred_at: 40.days.ago)
    create(:entry, user: user, repo_name: "builder/app", entry_type: "milestone", source: "manual", title: "Launched", occurred_at: 2.days.ago)
  end

  def json
    response.parsed_body
  end

  def totals
    json["numbers"].to_h { |number| [ number["key"], number["value"] ] }
  end

  it "answers the view asked for, camelCased, as the page renders it" do
    get "/api/progress/builder", params: { range: "30d" }

    expect(response).to have_http_status(:ok)
    expect(json).to include("range" => "30d", "words" => "last 30 days", "drawn" => [ "commits" ], "selected" => [])
    expect(totals).to eq("commits" => "3")
    expect(json["chart"]).to include("ariaLabel" => "7-day average of commits per day by project, last 30 days")
    expect(json["chart"]["paths"].map { |path| path.slice("number", "key") }).to eq([ { "number" => "commits", "key" => "builder/app" } ])
    expect(json["table"]["rows"].map { |row| [ row["name"], row["cells"].first["value"] ] }).to eq([ [ "app", "3" ], [ "lib", "0" ] ])
    expect(json["shipped"]["items"].map { |item| item["title"] }).to eq([ "Launched" ])

    get "/builder", params: { range: "30d" }
    expect(Nokogiri::HTML(response.body).at_css("[aria-label='Numbers on the chart']").text.squish).to eq("Commits 3")
  end

  it "narrows to the projects picked, as the old links still name them" do
    get "/api/progress/builder", params: { range: "90d", projects: "builder/lib" }
    expect(json).to include("selected" => [ "builder/lib" ])
    expect(totals).to eq("commits" => "1")
    expect(json["table"]["rows"].map { |row| [ row["name"], row["on"] ] }).to eq([ [ "app", false ], [ "lib", true ] ])

    get "/api/progress/builder", params: { range: "90d", repo: [ "builder/lib" ] }
    expect(json["selected"]).to eq([ "builder/lib" ])
  end

  it "shows every project for names that are none of the builder's" do
    get "/api/progress/builder", params: { range: "90d", projects: "builder/nope" }

    expect(json["selected"]).to eq([])
    expect(totals).to eq("commits" => "4")
  end

  it "counts an entry the builder hid from the lists, never a private one" do
    create(:github_repo, user: user, full_name: "builder/app", name: "app")
    create(:entry, user: user, repo_name: "builder/app", occurred_at: 1.day.ago, hidden: true)
    create(:entry, user: user, repo_name: "builder/app", occurred_at: 1.day.ago, visibility: :private_entry)

    get "/api/progress/builder", params: { range: "30d" }

    expect(totals).to eq("commits" => "4")
  end

  # A view reads entries five times: the cache key, the projects' commits
  # with when each began, when their entries began, the period's shipped and
  # published entries, and the commits by day, which the section and the
  # chart share. A read of its own for the chart's commits by day or first
  # commits would scan the builder's whole history a second time.
  it "reads the builder's commits by day once, and their first commits with the ranks, whichever view it answers" do
    sign_in_as(user)
    [ { range: "30d" }, { range: "all", projects: "builder/lib" }, { range: "12m", project: "builder/app" }, { range: "90d", dashboard: 1 } ].each do |params|
      reads = []
      counter = ->(*, payload) { reads << payload[:sql] if payload[:sql].include?('FROM "entries"') && !payload[:cached] }

      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { get "/api/progress/builder", params: params }

      by_day = reads.grep(/DATE\(\(entries\.occurred_at/)
      expect([ response.status, reads.size, by_day.size ]).to eq([ 200, 5, 1 ]), "#{params}:\n#{reads.join("\n")}"
    end
  end

  it "lets a browser revalidate a view it has" do
    get "/api/progress/builder", params: { range: "12m" }
    etag = response.headers["ETag"]

    get "/api/progress/builder", params: { range: "12m" }, headers: { "If-None-Match" => etag }
    expect(response).to have_http_status(:not_modified)
  end

  it "caches a view until the builder's public work changes, whatever order its numbers came in" do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    get "/api/progress/builder", params: { range: "30d", show: "commits,visits" }
    expect(totals).to eq("commits" => "3")

    allow(Progress::ChartService).to receive(:new).and_call_original
    get "/api/progress/builder", params: { range: "30d", show: "visits,commits" }
    expect(Progress::ChartService).not_to have_received(:new)

    user.entries.where(source: "github").first.update_columns(visibility: "private")
    get "/api/progress/builder", params: { range: "30d" }
    expect(totals).to eq("commits" => "2")
  end

  it "answers 404 for a builder who does not exist" do
    get "/api/progress/nobody"

    expect(response).to have_http_status(:not_found)
  end

  describe "site visits" do
    let!(:repo) do
      create(:github_repo, user: user, full_name: "builder/app", name: "app", homepage: "https://app.example",
                           site_source: "script", site_token: "os_a", site_first_visit_at: 2.days.ago)
    end

    before do
      repo.site_visit_days.create!(day: Date.new(2026, 10, 23), visits: 40, visitors: 12)
      user.update!(pro: true)
    end

    it "draws them beside the commits where the builder shows them, each number against its own peak" do
      get "/api/progress/builder", params: { range: "30d" }

      expect(totals).to eq("commits" => "3", "visits" => "40")
      expect(json["drawn"]).to eq(%w[commits visits])
      expect(json["chart"]["paths"].map { |path| path["number"] }).to contain_exactly("commits", "visits")
      expect(json["chart"]).to include("indexed" => true, "heads" => %w[commits visits])
      expect(response.headers["Cache-Control"]).to include("public")

      get "/api/progress/builder", params: { range: "30d", show: "visits" }
      expect(json["chart"]["ariaLabel"]).to eq("7-day average of site visits per day by project, last 30 days")
    end

    it "leaves out the ones the builder hides from visitors" do
      repo.update!(hidden_numbers: [ "visits" ])

      get "/api/progress/builder", params: { range: "90d", show: "visits" }
      expect(totals.keys).to eq([ "commits" ])
      expect(json["drawn"]).to eq([ "commits" ])
    end

    it "answers the dashboard to the builder alone, with what visitors do not see, and never into a shared cache" do
      repo.update!(hidden_numbers: [ "visits" ])

      get "/api/progress/builder", params: { range: "30d", dashboard: 1 }
      expect(json["table"]["rows"].first["switch"]).to be_nil
      expect(response.headers["Cache-Control"]).to include("private")

      sign_in_as(user)
      get "/api/progress/builder", params: { range: "30d", dashboard: 1 }
      cell = json["table"]["rows"].first["cells"].find { |each| each["key"] == "visits" }
      expect(cell).to include("value" => "40", "shown" => false, "pick" => false)
      expect(totals.keys).to eq([ "commits" ])
      expect(response.headers["Cache-Control"]).to include("private")
    end

    it "answers afresh once a project goes, as deleting the one Free counts hands its slot to the next" do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
      user.update!(pro: false)
      repo.update!(site_set_up_at: 3.days.ago)
      lib = create(:github_repo, user: user, full_name: "builder/lib", name: "lib", homepage: "https://lib.example",
                                 site_source: "script", site_token: "os_l", site_set_up_at: 2.days.ago, site_first_visit_at: 2.days.ago)
      lib.site_visit_days.create!(day: Date.new(2026, 10, 23), visits: 90, visitors: 30)
      get "/api/progress/builder", params: { range: "30d" }
      expect(totals["visits"]).to eq("40")

      repo.destroy!
      get "/api/progress/builder", params: { range: "30d" }
      expect(totals["visits"]).to eq("90")
    end

    it "answers a project's page for its project alone, with no table" do
      get "/api/progress/builder", params: { range: "30d", project: "builder/lib" }

      expect(totals).to eq("commits" => "0")
      expect(json["table"]).to be_nil
    end
  end
end
