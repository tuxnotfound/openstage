require "rails_helper"

RSpec.describe GithubRepo do
  let(:repo) { build(:github_repo, description: nil, readme_line: "From the README.", homepage: nil, preview_image_url: nil) }

  it "finds a builder's repos by full name, keyed by it" do
    user = create(:user)
    app = create(:github_repo, user: user, full_name: "me/app")
    create(:github_repo, user: user, full_name: "me/lib")
    create(:github_repo, full_name: "me/app")

    expect(user.github_repos.by_full_name([ "me/app", "me/gone" ])).to eq("me/app" => app)
  end

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

  it "shows every number its builder did not hide, and hides only numbers a project shows" do
    expect([ repo.picks?("commits"), repo.picks?("visits") ]).to eq([ true, true ])

    repo.hidden_numbers = [ "commits" ]
    expect([ repo.picks?("commits"), repo.picks?("visits") ]).to eq([ false, true ])

    repo.hidden_numbers = [ "views" ]
    expect(repo).not_to be_valid
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

      site.update!(hidden_numbers: [ "visits" ])
      expect(site.site_visits_public?).to be(false)

      site.update!(hidden_numbers: [], site_source: nil)
      expect(site.site_visits_public?).to be(false)
    end

    it "deletes its days and visitors, never orphans them" do
      site.site_visit_days.create!(day: Date.current, visits: 1, visitors: 1)
      site.site_visitors.create!(day: Date.current, visitor_hash: "a")

      site.site_visit_days.delete_all
      site.site_visitors.delete_all

      expect([ SiteVisitDay.count, SiteVisitor.count ]).to eq([ 0, 0 ])
    end

    it "refuses a source it does not know" do
      site.site_source = "vercel"

      expect(site).not_to be_valid
    end
  end
end
