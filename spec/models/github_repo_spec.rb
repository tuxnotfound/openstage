require "rails_helper"

RSpec.describe GithubRepo do
  let(:repo) { build(:github_repo, description: nil, readme_line: "From the README.", homepage: nil, preview_image_url: nil) }

  it "says what the project is in the builder's words, else GitHub's, else the README's" do
    expect(repo.project_description).to eq("From the README.")

    repo.description = "From GitHub."
    expect(repo.project_description).to eq("From GitHub.")

    repo.description_edit = "Mine."
    expect(repo.project_description).to eq("Mine.")
  end

  it "is live with a website to visit, the builder's own or GitHub's, as its Visit button is" do
    expect(repo.live?).to be(false)

    repo.website_edit = "https://mine.example"
    expect(repo.live?).to be(true)

    repo.website_edit = nil
    repo.homepage = "https://gh.example"
    expect(repo.live?).to be(true)

    repo.homepage = "gh.example"
    expect([ repo.live?, repo.outbound_url("visit") ]).to eq([ false, nil ])
  end

  it "lists what the project's page still lacks" do
    expect(repo.missing).to eq(%w[website picture])

    repo.preview_image_url = "https://repository-images.githubusercontent.com/1/x"
    expect(repo.missing).to eq(%w[website])
  end
end
