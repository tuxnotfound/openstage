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

  it "lists every repo with work, says what each page is missing, and leaves out repos with none" do
    get "/dashboard"

    expect(project_rows.keys).to eq(%w[builder/app builder/bare])
    expect(project_rows["builder/app"]).to include("Shown on your page · 3 commits in the last 90 days", "Add website and picture · Edit")
    expect(project_rows["builder/bare"]).to include("Add description, website, and picture · Edit")
    expect(page.at_css("[data-project-row='builder/bare'] a")["href"]).to eq("/projects/#{bare.id}/edit")
    expect(idle).to be_persisted
  end

  it "hides a project from the page with its switch, and keeps it listed to switch back" do
    get "/dashboard"
    switch = page.at_css("[data-project-row='builder/app'] button[role='switch']")
    expect(switch["aria-checked"]).to eq("true")

    patch "/github_repos/#{tool.id}", params: { included: "false" }
    expect(response).to redirect_to(dashboard_path)

    get "/dashboard"
    expect(project_rows["builder/app"]).to include("Hidden from your page")
    expect(page.at_css("[data-project-row='builder/app'] button[role='switch']")["aria-checked"]).to eq("false")
    expect(user.entries.where(repo_name: "builder/app").pluck(:hidden).uniq).to eq([ true ])
  end
end
