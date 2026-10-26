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

  describe "site visits" do
    let(:user) { create(:user, pro: true) }
    let(:site) { create(:github_repo, user: user, website_edit: "https://Shipnote.app/home", site_source: "script") }

    it "counts on the website's host" do
      expect(site.site_host).to eq("shipnote.app")
    end

    it "shows them on its page once one came, while switched on and counting" do
      expect(site.site_visits_public?).to be(false)

      site.update!(site_first_visit_at: Time.current)
      expect(site.site_visits_public?).to be(true)

      site.update!(site_visits_shown: false)
      expect(site.site_visits_public?).to be(false)

      site.update!(site_visits_shown: true, site_source: nil)
      expect(site.site_visits_public?).to be(false)
    end

    it "refuses a source it does not know" do
      site.site_source = "vercel"

      expect(site).not_to be_valid
    end
  end
end
