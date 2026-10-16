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

  def section
    Nokogiri::HTML(response.body).at_css("turbo-frame#progress section")
  end

  it "tells the owner how many entries have no project, and never a visitor" do
    get "/tux"
    expect(section.text).not_to include("have no project")

    sign_in_as(user)
    get "/tux"
    expect(section.text.squish).to include("19 entries in 2026 have no project. Tag them")

    get "/tux", params: { repo: progress_repo(0) }
    expect(section.text.squish).to include("19 entries in 2026 have no project, so this view leaves them out.")
  end

  it "opens the panel with the projects that had commits that day first, busiest first" do
    sign_in_as(user)
    get "/tux", params: { tag: "1", range: "month" }

    row = section.at_css("[data-tag-row='#{post.id}']")
    expect(row.css("button").map { |button| button.text.squish })
      .to eq([ "trained-on · 5 that day", "openstage · 2 that day", "No project" ])
    expect(section.css("[data-tag-row]").size).to eq(2)
  end

  it "offers every picked project first when several are picked" do
    sign_in_as(user)
    get "/tux", params: { tag: "1", range: "month", repo: [ progress_repo(0), progress_repo(1) ] }

    row = section.at_css("[data-tag-row='#{post.id}']")
    expect(row.css("button").map { |button| button.text.squish })
      .to eq([ "openstage", "wheels-off", "trained-on · 5 that day", "No project" ])
  end

  it "tags any entry type and redraws the period with the panel open" do
    sign_in_as(user)
    patch "/entries/#{post.id}/project", params: { repo_name: progress_repo(4), range: "month", offset: "0" }

    expect(response).to redirect_to("/tux?offset=0&range=month&tag=1")
    expect(post.reload.repo_name).to eq(progress_repo(4))
    follow_redirect!
    expect(section.css("[data-tag-row]").size).to eq(1)
  end

  it "marks an entry as having no project, which takes it off the backlog for good" do
    sign_in_as(user)
    patch "/entries/#{post.id}/project", params: { no_project: "1" }

    expect(post.reload).to have_attributes(no_project: true, repo_name: nil)
    get "/tux"
    expect(section.text).to include("18 entries in 2026 have no project")

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
