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

  it "is live only with a website on GitHub, whatever the builder adds" do
    repo.website_edit = "https://mine.example"
    expect([ repo.website, repo.live? ]).to eq([ "https://mine.example", false ])

    repo.homepage = "https://gh.example"
    expect(repo.live?).to be(true)
  end

  it "lists what the project's page still lacks" do
    expect(repo.missing).to eq(%w[website picture])

    repo.preview_image_url = "https://repository-images.githubusercontent.com/1/x"
    expect(repo.missing).to eq(%w[website])
  end
end
