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
    page.css("[data-project-row]").to_h { |row| [ row["data-project-row"], row.text.squish ] }
  end

  it "charts the last 90 days of the builder's work, and keeps the entry filters on its window links" do
    get "/dashboard", params: { q: "work" }

    activity = page.at_css("section[aria-labelledby='your-activity']")
    expect(activity.text.squish).to include("4 commits, last 90 days")
    expect(activity.at_css("svg[role='img']")["aria-label"]).to eq("Commits per week by project, last 90 days")
    month = activity.css("nav[aria-label='Time range'] a").find { |a| a.text == "30 days" }
    expect(month["href"]).to eq("/dashboard?q=work&range=30d")
  end

  it "lists every repo with work, each with Edit, and leaves out repos with none" do
    get "/dashboard"

    expect(project_rows.keys).to eq(%w[builder/app builder/bare])
    expect(project_rows["builder/app"]).to include("app 3 commits Edit")
    expect(project_rows["builder/app"]).not_to include("Add website")
    expect(page.at_css("[data-project-row='builder/bare'] a.os-btn2")["href"]).to eq("/projects/#{bare.id}/edit")
    expect(idle).to be_persisted
  end

  it "hides a project from the page with its switch, and keeps it listed to switch back" do
    get "/dashboard"
    switch = page.at_css("[data-project-row='builder/app'] button[role='switch']")
    expect(switch["aria-checked"]).to eq("true")

    patch "/github_repos/#{tool.id}", params: { included: "false" }
    expect(response).to redirect_to("/dashboard#activity")

    get "/dashboard"
    expect(project_rows["builder/app"]).to include("Hidden")
    expect(page.at_css("[data-project-row='builder/app'] button[role='switch']")["aria-checked"]).to eq("false")
    expect(user.entries.where(repo_name: "builder/app").pluck(:hidden).uniq).to eq([ true ])
  end

  describe "site visits on Your activity" do
    before do
      tool.update!(homepage: "https://app.example", site_source: "script", site_first_visit_at: 2.days.ago, site_visits_shown: false)
      tool.site_visit_days.create!(day: 1.day.ago.to_date, visits: 90, visitors: 30)
    end

    it "draws a project's visits beside its commits, shown on its page or not, with a chip to leave them out" do
      get "/dashboard"

      expect(page.at_css("section[aria-labelledby='your-activity']").text.squish).to include("90 site visits")
      expect(response.body).to include("app · site visits", "Solid: commits. Dotted: site visits.")
      chip = page.at_css("[data-project-row='builder/app'] form[action='/projects/#{tool.id}/dashboard_numbers'] button")
      expect(chip["aria-pressed"]).to eq("true")
      expect(page.at_css("[data-project-row='builder/bare'] form[action$='/dashboard_numbers']")).to be_nil

      patch "/projects/#{tool.id}/dashboard_numbers", params: { number: "visits", on: "false" }
      expect(response).to redirect_to(dashboard_path(anchor: "your-activity"))
      expect(tool.reload.dashboard_numbers).to eq([])

      get "/dashboard"
      expect(response.body).not_to include("app · site visits")
    end

    it "refuses a number the dashboard cannot draw, and someone else's project" do
      patch "/projects/#{tool.id}/dashboard_numbers", params: { number: "mrr", on: "true" }
      expect(tool.reload.dashboard_numbers).to eq([ "visits" ])

      theirs = create(:github_repo, user: create(:user))
      patch "/projects/#{theirs.id}/dashboard_numbers", params: { number: "visits", on: "false" }
      expect(response).to have_http_status(:not_found)
    end
  end
end
