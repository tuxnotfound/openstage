require "rails_helper"

RSpec.describe "Editing a project", type: :request do
  let(:user) { create(:user, username: "builder") }
  let!(:repo) { create(:github_repo, user: user, name: "app", full_name: "builder/app", description: "From GitHub.", homepage: "https://gh.example") }

  before { sign_in_as(user) }

  it "opens the form in the project's row, showing what GitHub says" do
    get "/projects/#{repo.id}/edit"

    form = Nokogiri::HTML(response.body).at_css("turbo-frame#project_github_repo_#{repo.id} form")
    expect(form.at_css("textarea")["placeholder"]).to eq("From GitHub.")
    expect(form.at_css("input[name='github_repo[website_edit]']")["placeholder"]).to eq("https://gh.example")
  end

  it "keeps the builder's words over GitHub's, and goes back to GitHub's when cleared" do
    patch "/projects/#{repo.id}", params: { github_repo: { description_edit: "  My own words.  ", website_edit: "https://mine.example", image_edit: "" } }

    expect(response).to redirect_to(dashboard_path)
    expect(repo.reload).to have_attributes(project_description: "My own words.", website: "https://mine.example", image_edit: nil)

    patch "/projects/#{repo.id}", params: { github_repo: { description_edit: "", website_edit: "" } }
    expect(repo.reload).to have_attributes(project_description: "From GitHub.", website: "https://gh.example")
  end

  it "refuses a website that is not a web address, and says why" do
    patch "/projects/#{repo.id}", params: { github_repo: { website_edit: "javascript:alert(1)" } }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.body).to include("must start with http:// or https://")
    expect(repo.reload.website_edit).to be_nil
  end

  it "never edits someone else's project" do
    theirs = create(:github_repo, user: create(:user))

    patch "/projects/#{theirs.id}", params: { github_repo: { description_edit: "mine now" } }

    expect(response).to have_http_status(:not_found)
    expect(theirs.reload.description_edit).to be_nil
  end
end
