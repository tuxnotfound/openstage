require "rails_helper"

RSpec.describe "Editing a project", type: :request do
  let(:user) { create(:user, username: "builder") }
  let!(:repo) { create(:github_repo, user: user, name: "app", full_name: "builder/app", description: "From GitHub.", homepage: "https://gh.example") }

  before { sign_in_as(user) }

  it "opens the project as its builder sees it, laid out like its page, with the form showing what GitHub says" do
    get "/projects/#{repo.id}/edit"

    page = Nokogiri::HTML(response.body)
    expect(page.at_css("turbo-frame")).to be_nil
    expect(page.at_css("h1#project-name").text.squish).to eq("app")
    form = page.at_css("form[action='/projects/#{repo.id}']")
    expect(form.at_css("textarea")["placeholder"]).to eq("From GitHub.")
    expect(form.at_css("input[name='github_repo[website_edit]']")["placeholder"]).to eq("https://gh.example")
    expect(page.at_css("h2#numbers").text).to eq("Numbers on its page")
    expect(page.at_css("a[href='/builder/app']").text).to include("View its page")
  end

  it "switches the project on and off the builder's page from its view, and comes back to it" do
    patch "/github_repos/#{repo.id}", params: { included: "false", back: "project" }

    expect(response).to redirect_to(edit_project_path(repo))
    expect(repo.reload.included).to be(false)
  end

  it "keeps the builder's words over GitHub's, and goes back to GitHub's when cleared" do
    patch "/projects/#{repo.id}", params: { github_repo: { description_edit: "  My own words.  ", website_edit: "https://mine.example", image_edit: "" } }

    expect(response).to redirect_to(edit_project_path(repo))
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
