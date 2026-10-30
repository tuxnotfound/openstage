require "rails_helper"

# The dashboard used to render every entry with no pagination or search, so
# acting on an old one meant scrolling the entire history.
RSpec.describe "Dashboard search and paging", type: :request do
  let(:user) { create(:user, username: "builder") }

  before { sign_in_as(user) }

  it "pages instead of dumping every entry on the page" do
    create_list(:entry, EntriesSection::PER_PAGE + 5, user: user)

    get "/dashboard"
    expect(response.body).to include("Load more")
    expect(response.body.scan(/id="entry-\d+"/).size).to eq(EntriesSection::PER_PAGE)
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

  describe "the repo filter" do
    before do
      create(:entry, user: user, title: "openstage work", repo_name: "builder/openstage")
      create(:entry, user: user, title: "goal atlas work", repo_name: "builder/goal_atlas")
    end

    it "shows only the chosen repo's entries" do
      get "/dashboard", params: { repo: "builder/openstage" }

      expect(response.body).to include("openstage work")
      expect(response.body).not_to include("goal atlas work")
      expect(response.body).to include("1 entry of 2")
      expect(response.body).to include('<option selected="selected" value="builder/openstage">openstage</option>')
    end

    it "ignores a repo with no entries rather than returning nothing" do
      get "/dashboard", params: { repo: "builder/unknown" }

      expect(response.body).to include("openstage work", "goal atlas work")
    end

    it "keeps the repo on the Load more link" do
      create_list(:entry, EntriesSection::PER_PAGE, user: user, repo_name: "builder/openstage")

      get "/dashboard", params: { repo: "builder/openstage" }

      expect(response.body).to include("repo=builder%2Fopenstage")
    end
  end

  it "offers no repo filter while every entry comes from one repo" do
    create(:entry, user: user, repo_name: "builder/openstage")

    get "/dashboard"
    expect(response.body).not_to include("All repos")
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
    create_list(:entry, EntriesSection::PER_PAGE + 2, user: user, title: "findable thing")

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
      create_list(:entry, EntriesSection::PER_PAGE + 2, user: user)
      get "/dashboard"
      more = Nokogiri::HTML(response.body).at_css("#entries-more-timeline a")["href"]

      get more, headers: turbo_accept

      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include('turbo-stream action="append" target="entries-list-timeline"')
      expect(response.body.scan(/id="entry-\d+"/).size).to eq(2)
      expect(response.body).to include('turbo-stream action="remove" target="entries-more-timeline"')
    end

    # Rows hidden in place above the last one shown used to shift a page
    # number's next page past entries never shown.
    it "starts the next page past the last row shown, whatever was hidden above it" do
      oldest = create(:entry, user: user, title: "The oldest", occurred_at: 2.years.ago)
      create_list(:entry, EntriesSection::PER_PAGE, user: user, occurred_at: 1.day.ago)
      get "/dashboard"
      more = Nokogiri::HTML(response.body).at_css("#entries-more-timeline a")["href"]

      user.entries.where.not(id: oldest.id).first.update!(hidden: true)
      get more, headers: turbo_accept

      expect(response.body).to include("The oldest")
    end

    # The filters redraw the tabs and lists in their frame alone: the rest of
    # the page is never rendered for it, and each list's links leave it.
    it "renders only the tabs and lists for a filter" do
      create(:entry, user: user, title: "the needle")
      create(:entry, user: user, title: "a haystack")

      get "/dashboard", params: { q: "needle" }, headers: { "Turbo-Frame" => "entries-lists" }

      page = Nokogiri::HTML(response.body)
      expect(page.css("#entries-tabs a").map(&:text)).to eq([ "Entries (1)" ])
      expect(page.at_css("turbo-frame#entries-lists turbo-frame#entries-timeline[target='_top']").text).to include("the needle", "1 entry of 2")
      expect(response.body).not_to include("a haystack", "This week", "Search your entries")
    end
  end

  # One search, type and repo narrow every tab, and each tab's count with them.
  describe "the filters on Hidden and Private" do
    before do
      user.update!(pro: true)
      create(:entry, user: user, title: "shown fix", repo_name: "builder/app")
      create(:entry, user: user, title: "hidden fix", repo_name: "builder/off", hidden: true)
      create(:entry, user: user, title: "hidden chore", repo_name: "builder/off", hidden: true)
      create(:entry, user: user, source: "manual", entry_type: "note", title: "private fix", visibility: :private_entry)
    end

    def page
      Nokogiri::HTML(response.body)
    end

    it "narrows every tab and counts what each matches, the tabs shown as before" do
      get "/dashboard", params: { q: "fix", tab: "hidden" }

      expect(page.css("#entries-tabs a").map(&:text)).to eq([ "Entries (2)", "Hidden (1)", "Private (1)" ])
      expect(page.at_css("#entries-hidden").text.squish).to include("1 entry of 2", "hidden fix")
      expect(page.at_css("#entries-hidden").text).not_to include("hidden chore")
      expect(page.at_css("#entries-private").text.squish).to include("1 entry of 1", "private fix")
      expect(page.at_css("[data-tabs-panel='hidden']")["class"]).not_to include("hidden")
    end

    it "keeps a tab whose entries the filters all leave out, saying none match" do
      get "/dashboard", params: { q: "chore", tab: "private" }

      expect(page.css("#entries-tabs a").map(&:text)).to eq([ "Entries (0)", "Hidden (1)", "Private (0)" ])
      expect(page.at_css("#entries-private").text).to include("No entries match that.")
    end

    it "offers the repos only hidden entries come from" do
      get "/dashboard", params: { repo: "builder/off", tab: "hidden" }

      expect(page.css("select[name='repo'] option").map { |option| option["value"] }).to include("builder/off", "builder/app")
      expect(page.css("#entries-tabs a").map(&:text)).to eq([ "Entries (0)", "Hidden (2)", "Private (0)" ])
    end

    it "pages the hidden list under the filters" do
      create_list(:entry, EntriesSection::PER_PAGE, user: user, title: "another hidden fix", hidden: true, occurred_at: 1.day.ago)
      create(:entry, user: user, title: "the oldest hidden fix", hidden: true, occurred_at: 1.year.ago)
      get "/dashboard", params: { q: "fix", tab: "hidden" }
      more = page.at_css("#entries-more-hidden a")["href"]
      expect(more).to include("q=fix", "tab=hidden")

      get more, headers: { "Accept" => "text/vnd.turbo-stream.html, text/html" }

      expect(response.body).to include('target="entries-list-hidden"', "the oldest hidden fix")
    end
  end

  # Without JavaScript the tabs are links and Load more opens the next page.
  describe "without JavaScript" do
    it "opens the tab a link names, with its list" do
      create(:entry, user: user, title: "Out of sight", hidden: true)

      get "/dashboard", params: { tab: "hidden" }

      page = Nokogiri::HTML(response.body)
      expect(page.at_css("[data-tabs-panel='hidden']")["class"]).not_to include("hidden")
      expect(page.at_css("[data-tabs-panel='timeline']")["class"]).to include("hidden")
      expect(page.css("#entries-tabs a").map { |tab| [ tab.text, tab["href"] ] })
        .to eq([ [ "Entries (0)", "/dashboard?tab=timeline#entries" ], [ "Hidden (1)", "/dashboard?tab=hidden#entries" ] ])
      expect(page.at_css("#entries-hidden").text).to include("Out of sight", "Restore")
    end

    it "opens the timeline when the tab asked for holds nothing" do
      get "/dashboard", params: { tab: "hidden" }

      expect(Nokogiri::HTML(response.body).at_css("[data-tabs-panel='timeline']")["class"]).not_to include("hidden")
    end

    it "opens the page past the last row shown for Load more" do
      create(:entry, user: user, title: "The oldest", occurred_at: 2.years.ago)
      create_list(:entry, EntriesSection::PER_PAGE, user: user, occurred_at: 1.day.ago)
      get "/dashboard"

      get Nokogiri::HTML(response.body).at_css("#entries-more-timeline a")["href"]

      expect(response.body.scan(/id="entry-\d+"/).size).to eq(1)
      expect(response.body).to include("The oldest")
    end
  end
end
