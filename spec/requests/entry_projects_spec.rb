require "rails_helper"
require "support/progress_data"

RSpec.describe "Tagging entries with a project" do
  include ProgressData

  let(:user) { create(:user, username: "tux") }
  let(:post) { progress_entry(user, 20) }

  before do
    seed_progress_data(user)
    travel_to ProgressData::TODAY
  end

  let(:year) { Date.new(2025, 11, 1)..ProgressData::TODAY.to_date }

  def section
    Nokogiri::HTML(response.body).at_css("turbo-frame#untagged")
  end

  # The tag panel is the builder's chore: on their dashboard, never on their
  # stage, even while they look at it signed in (Pedro, 2026-10-30).
  it "tells the builder on their dashboard how many entries have no project, and never on their stage" do
    sign_in_as(user)
    get "/tux"
    expect(response.body).not_to include("have no project", "Tag them")

    get "/dashboard"
    expect(section.text.squish).to include("#{progress_untagged(year)} entries in the last 12 months have no project. Tag them")
    expect(section.at_css("a")["href"]).to eq("/dashboard?tag=1#activity")
  end

  # The chart above may show 90 days or one project; the backlog is the
  # same last 12 months, as the stage showed it before.
  it "counts the last 12 months whatever the chart shows, and keeps the chart's view on its links" do
    sign_in_as(user)
    get "/dashboard", params: { range: "30d", projects: progress_repo(0) }

    expect(section.text.squish).to include("#{progress_untagged(year)} entries in the last 12 months have no project.")
    expect(section.at_css("a")["href"]).to eq("/dashboard?projects=#{CGI.escape(progress_repo(0))}&range=30d&tag=1#activity")
  end

  it "redraws the panel alone in its frame, a row for each entry it counts" do
    sign_in_as(user)
    get "/dashboard", params: { tag: "1", range: "30d" }, headers: { "Turbo-Frame" => "untagged" }

    expect(section.css("[data-tag-row]").size).to eq(progress_untagged(year))
    expect(response.body).to start_with('<turbo-frame id="untagged">')
    expect(response.body).not_to include("<html", "Search your entries")
  end

  it "opens the panel with the projects that had commits that day first, busiest first" do
    sign_in_as(user)
    get "/dashboard", params: { tag: "1", range: "30d" }

    row = section.at_css("[data-tag-row='#{post.id}']")
    expect(row.css("button").map { |button| button.text.squish })
      .to eq([ "trained-on · 5 that day", "openstage · 2 that day", "No project" ])
  end

  it "tags any entry type and redraws the period with the panel open" do
    sign_in_as(user)
    patch "/entries/#{post.id}/project", params: { repo_name: progress_repo(4), range: "30d" }

    expect(response).to redirect_to("/dashboard?range=30d&tag=1#activity")
    expect(post.reload.repo_name).to eq(progress_repo(4))
    follow_redirect!
    expect(section.css("[data-tag-row]").size).to eq(progress_untagged(year) - 1)
  end

  it "marks an entry as having no project, which takes it off the backlog for good" do
    sign_in_as(user)
    patch "/entries/#{post.id}/project", params: { no_project: "1" }

    expect(post.reload).to have_attributes(no_project: true, repo_name: nil)
    get "/dashboard"
    expect(section.text).to include("#{progress_untagged(year) - 1} entries in the last 12 months have no project")

    patch "/entries/#{post.id}/project", params: { repo_name: progress_repo(0) }
    expect(post.reload).to have_attributes(no_project: false, repo_name: progress_repo(0))
  end

  it "refuses a click that names no project" do
    sign_in_as(user)
    patch "/entries/#{post.id}/project", params: { repo_name: " " }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(post.reload.repo_name).to be_nil
  end

  it "never tags someone else's entry" do
    sign_in_as(create(:user))
    patch "/entries/#{post.id}/project", params: { repo_name: "me/mine" }

    expect(response).to have_http_status(:not_found)
    expect(post.reload.repo_name).to be_nil
  end

  it "sends a visitor to sign in" do
    patch "/entries/#{post.id}/project", params: { repo_name: "me/mine" }

    expect(response).to redirect_to(root_path)
    expect(post.reload.repo_name).to be_nil
  end

  it "refuses a request without the page's CSRF token" do
    sign_in_as(user)
    ActionController::Base.allow_forgery_protection = true

    patch "/entries/#{post.id}/project", params: { repo_name: progress_repo(4) }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(post.reload.repo_name).to be_nil
  ensure
    ActionController::Base.allow_forgery_protection = false
  end
end
