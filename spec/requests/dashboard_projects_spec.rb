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
    page.css("#activity-lines [data-line-row]").to_h { |row| [ row["data-line-row"], row.text.squish ] }
  end

  def page_switch(repo)
    page.at_css("[data-line-row='#{repo}'] form[action^='/github_repos/'] button[role='switch']")
  end

  it "charts the last 90 days of the builder's work, and keeps the entry filters on its window links" do
    get "/dashboard", params: { q: "work" }

    activity = page.at_css("section[aria-labelledby='your-activity']")
    expect(activity.at_css("nav[aria-label='Numbers']").text.squish).to eq("Commits 4")
    expect(activity.at_css("svg[role='img']")["aria-label"]).to eq("Commits per week by project, last 90 days")
    month = activity.css("nav[aria-label='Time range'] a").find { |a| a.text == "30 days" }
    expect(month["href"]).to eq("/dashboard?q=work&range=30d")
  end

  it "lists every repo with work under the chart, each with Edit up front, and leaves out repos with none" do
    get "/dashboard"

    expect(project_rows.keys).to eq(%w[builder/app builder/bare])
    expect(project_rows["builder/app"]).to start_with("app Edit")
    expect(page.at_css("[data-line-row='builder/bare'] a.os-btn2")["href"]).to eq("/projects/#{bare.id}/edit")
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
    expect(page.css("[data-line-row='builder/app'] td").map { |cell| cell.text.squish }.last(2)).to eq([ "Commits –", "Site visits –" ])
    expect(user.entries.where(repo_name: "builder/app").pluck(:hidden).uniq).to eq([ true ])
  end

  describe "the table under Your activity" do
    before do
      tool.update!(homepage: "https://app.example", site_source: "script", site_first_visit_at: 2.days.ago, site_visits_shown: false)
      tool.site_visit_days.create!(day: 1.day.ago.to_date, visits: 90, visitors: 30)
    end

    def cells(repo)
      page.css("[data-line-row='#{repo}'] td").map do |cell|
        [ cell.text.squish.sub(/\A(On the chart|Your page|Commits|Site visits) ?/, ""), cell.at_css("[role='switch']")&.[]("aria-checked") ]
      end
    end

    it "lists each project's numbers, the site visits of one hidden from its page too, and a chart for each" do
      get "/dashboard"

      expect(cells("builder/app")).to eq([ [ "", "true" ], [ "", "true" ], [ "3", nil ], [ "90", nil ] ])
      expect(cells("builder/bare")).to eq([ [ "", "true" ], [ "", "true" ], [ "1", nil ], [ "Set up", nil ] ])
      expect(page.at_css("[data-line-row='builder/bare'] a[aria-label^='Set up']")["href"]).to eq("/projects/#{bare.id}/edit?site=open#site-visits")
      activity = page.at_css("section[aria-labelledby='your-activity']")
      expect(activity.at_css("nav[aria-label='Numbers']").text.squish).to eq("Commits 4 Site visits 90")
      expect(activity.css("section[aria-label]").map { |chart| chart["aria-label"] }).to eq([ "Commits", "Site visits" ])
    end

    it "switches a project off the chart, keeping the others, and back" do
      get "/dashboard"
      switch = page.at_css("[data-line-row='builder/app'] a[role='switch']")
      expect(Rack::Utils.parse_nested_query(URI(switch["href"]).query)["repo"]).to eq([ "builder/bare" ])

      get switch["href"]
      expect(cells("builder/app").first).to eq([ "", "false" ])
      back = page.at_css("[data-line-row='builder/app'] a[role='switch']")["href"]
      expect(Rack::Utils.parse_nested_query(URI(back).query)["repo"]).to be_nil
    end

    it "charts only the numbers picked" do
      get "/dashboard", params: { show: [ "visits" ] }

      expect(page.css("section[aria-labelledby='your-activity'] section[aria-label]").map { |chart| chart["aria-label"] }).to eq([ "Site visits" ])
    end
  end
end
