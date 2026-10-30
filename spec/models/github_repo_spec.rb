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
    expect([ repo.picks?("commits"), repo.picks?("visits"), repo.picks?("site_visitors") ]).to eq([ true, true, true ])

    repo.hidden_numbers = [ "commits", "site_visitors" ]
    expect([ repo.picks?("commits"), repo.picks?("visits"), repo.picks?("site_visitors") ]).to eq([ false, true, false ])
    expect(repo).to be_valid

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
      expect(site.site_number_public?("visits")).to be(false)

      site.update!(site_first_visit_at: Time.current)
      expect(site.site_number_public?("visits")).to be(true)

      site.update!(hidden_numbers: [ "visits" ])
      expect(site.site_number_public?("visits")).to be(false)

      site.update!(hidden_numbers: [], site_source: nil)
      expect(site.site_number_public?("visits")).to be(false)
    end

    it "shows its site visitors as it shows its site visits, each with its own switch" do
      public_numbers = -> { %w[commits visits site_visitors].select { |number| site.reload.public_number?(number) } }
      expect(public_numbers.call).to eq(%w[commits])

      site.update!(site_first_visit_at: Time.current)
      expect(public_numbers.call).to eq(%w[commits visits site_visitors])

      site.update!(hidden_numbers: [ "site_visitors" ])
      expect(public_numbers.call).to eq(%w[commits visits])

      site.update!(hidden_numbers: [], site_source: nil)
      expect(public_numbers.call).to eq(%w[commits])
    end

    it "keeps a Free builder's site visitors off every project but the one set up first" do
      user.update!(pro: false)
      first = create(:github_repo, user: user, homepage: "https://first.example", site_source: "script", site_set_up_at: 2.days.ago,
                                   site_first_visit_at: 1.day.ago)
      site.update!(site_set_up_at: 1.day.ago, site_first_visit_at: Time.current)

      expect([ first.public_number?("site_visitors"), site.public_number?("site_visitors") ]).to eq([ true, false ])
    end

    it "deletes its days, counts and visitors, never orphans them" do
      site.site_visit_days.create!(day: Date.current, visits: 1, visitors: 1)
      site.site_visit_counts.create!(day: Date.current, kind: "page", value: "/", count: 1)
      site.site_visitors.create!(day: Date.current, visitor_hash: "a")

      site.site_visit_days.delete_all
      site.site_visit_counts.delete_all
      site.site_visitors.delete_all

      expect([ SiteVisitDay.count, SiteVisitCount.count, SiteVisitor.count ]).to eq([ 0, 0, 0 ])
    end

    it "takes its days and counts with it, destroyed or deleted in the database" do
      other = create(:github_repo, user: user)
      [ site, other ].each do |repo|
        repo.site_visit_days.create!(day: Date.current, visits: 1, visitors: 1)
        repo.site_visit_counts.create!(day: Date.current, kind: "source", value: "github.com", count: 1)
      end

      site.destroy!
      GithubRepo.where(id: other.id).delete_all

      expect([ SiteVisitDay.count, SiteVisitCount.count ]).to eq([ 0, 0 ])
    end

    it "refuses a source it does not know" do
      site.site_source = "vercel"

      expect(site).not_to be_valid
    end
  end
end
