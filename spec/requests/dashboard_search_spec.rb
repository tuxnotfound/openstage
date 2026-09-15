require "rails_helper"

# The dashboard used to render every entry with no pagination or search, so
# acting on an old one meant scrolling the entire history.
RSpec.describe "Dashboard search and paging", type: :request do
  let(:user) { create(:user, username: "builder") }

  before { sign_in_as(user) }

  it "pages instead of dumping every entry on the page" do
    create_list(:entry, DashboardController::PER_PAGE + 5, user: user)

    get "/dashboard"
    expect(response.body).to include("Load more")
    expect(response.body.scan(/id="entry-\d+"/).size).to eq(DashboardController::PER_PAGE)
  end

  it "does not offer Load more when everything already fits" do
    create_list(:entry, 3, user: user)

    get "/dashboard"
    expect(response.body).not_to include("Load more")
  end

  it "finds an old entry by title without scrolling" do
    create_list(:entry, 30, user: user, title: "routine commit")
    create(:entry, user: user, title: "the needle I am looking for", occurred_at: 2.years.ago)

    get "/dashboard", params: { q: "needle" }

    expect(response.body).to include("the needle I am looking for")
    expect(response.body).to include("1 entry of 31")
  end

  it "searches the project name too" do
    create(:entry, user: user, title: "some work", repo_name: "tuxnotfound/curbcut")

    get "/dashboard", params: { q: "curbcut" }
    expect(response.body).to include("some work")
  end

  it "filters by entry type" do
    create(:entry, user: user, entry_type: "milestone", title: "a milestone")
    create(:entry, user: user, entry_type: "shipped", title: "a commit")

    get "/dashboard", params: { type: "milestone" }

    expect(response.body).to include("a milestone")
    expect(response.body).not_to include("a commit")
  end

  it "ignores an unknown type rather than returning nothing" do
    create(:entry, user: user, title: "still here")

    get "/dashboard", params: { type: "nonsense" }
    expect(response.body).to include("still here")
  end

  it "says so when a search matches nothing" do
    create(:entry, user: user, title: "something")

    get "/dashboard", params: { q: "zzzznomatch" }
    expect(response.body).to include("No entries match that")
  end

  it "treats a search term with SQL wildcards literally" do
    create(:entry, user: user, title: "100% done")
    create(:entry, user: user, title: "unrelated")

    get "/dashboard", params: { q: "100%" }

    expect(response.body).to include("100% done")
    expect(response.body).not_to include("unrelated")
  end

  it "keeps the filters on the Load more link" do
    create_list(:entry, DashboardController::PER_PAGE + 2, user: user, title: "findable thing")

    get "/dashboard", params: { q: "findable" }

    expect(response.body).to include("q=findable")
  end

  describe "Turbo requests" do
    let(:turbo_accept) { { "Accept" => "text/vnd.turbo-stream.html, text/html, application/xhtml+xml" } }

    # A Turbo form that redirects to the dashboard (Sync now, entry actions)
    # follows the 302 with this Accept header. It used to get the Load more
    # stream, so the flash waited for a refresh and page 1 was appended again.
    it "renders the full page with its flash after a Turbo form redirects here" do
      allow(GithubSyncJob).to receive(:perform_later)
      post "/sync/github", headers: turbo_accept
      follow_redirect!(headers: turbo_accept)

      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("GitHub sync started")
    end

    it "still appends the next page for Load more" do
      create_list(:entry, DashboardController::PER_PAGE + 2, user: user)

      get "/dashboard", params: { page: 2 }, headers: turbo_accept

      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('turbo-stream action="append" target="dashboard-entries"')
    end
  end
end
