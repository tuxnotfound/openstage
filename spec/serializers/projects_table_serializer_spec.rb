require "rails_helper"

RSpec.describe ProjectsTableSerializer do
  let(:user) { create(:user, pro: true) }
  let!(:app) { create(:github_repo, user: user, full_name: "me/app", name: "app", homepage: "https://app.example", site_source: "script", site_first_visit_at: 3.days.ago) }
  let!(:lib) { create(:github_repo, user: user, full_name: "me/lib", name: "lib") }

  before do
    travel_to Time.utc(2026, 10, 28, 12)
    create(:entry, user: user, repo_name: "me/app", occurred_at: 2.days.ago)
    create(:entry, user: user, repo_name: "me/lib", occurred_at: 3.days.ago)
    app.site_visit_days.create!(day: Date.new(2026, 10, 27), visits: 1204, visitors: 800)
  end

  def table(changes: false, **options)
    chart = Progress::ChartService.new(user: user, range: "30d", **options).tap(&:call!)
    described_class.new(chart, changes: changes, manage: chart.builder.present?, off_page: chart.off_page).as_json
  end

  def cells(json, name)
    json["rows"].find { |row| row["name"] == name }["cells"].to_h { |cell| [ cell["key"], cell.slice("value", "shown", "pick", "setup") ] }
  end

  it "fills a project's cells with the numbers its visitors see, and leaves the rest empty" do
    app.update!(hidden_numbers: [ "visits" ])
    json = table

    expect(json["columns"]).to eq([ { "key" => "commits", "label" => "Commits", "word" => "commits" } ])
    expect(cells(json, "app")).to eq("commits" => { "value" => "1", "shown" => true, "pick" => nil, "setup" => nil })
    expect(json["rows"].first).to include("edit" => nil, "page" => nil, "switch" => nil, "drawable" => true)
  end

  it "gives each cell visitors see its change against the window before, when asked, and only while it counted before" do
    create(:entry, user: user, repo_name: "me/app", occurred_at: 40.days.ago)
    json = table(changes: true)

    expect(cells(json, "app")["commits"]).to include("value" => "1")
    expect(json["rows"].map { |row| [ row["name"], row["cells"].to_h { |cell| [ cell["key"], cell["change"] ] } ] })
      .to eq([ [ "app", { "commits" => { "arrow" => "±", "text" => "0%", "up" => nil }, "visits" => nil } ], [ "lib", { "commits" => nil, "visits" => nil } ] ])
    expect(table["rows"].flat_map { |row| row["cells"].pluck("change") }.uniq).to eq([ nil ])
  end

  it "gives the builder every value with its switch, Set up where a project counts no site visits, and the projects off their page last" do
    app.update!(hidden_numbers: [ "visits" ])
    create(:github_repo, user: user, full_name: "me/old", name: "old", included: false)
    create(:entry, user: user, repo_name: "me/old", occurred_at: 2.days.ago)
    json = table(builder: true)

    expect(cells(json, "app")["visits"]).to eq("value" => "1,204", "shown" => false, "pick" => false, "setup" => nil)
    expect(cells(json, "lib")["visits"]).to eq("value" => nil, "shown" => false, "pick" => nil, "setup" => "/projects/#{lib.id}/edit?site=open#site-visits")
    expect(json["rows"].last).to include("name" => "old", "drawable" => false, "on" => false)
    expect(json["rows"].last["page"]).to eq("on" => false, "path" => "/github_repos/#{user.github_repos.find_by(name: 'old').id}")
  end
end
