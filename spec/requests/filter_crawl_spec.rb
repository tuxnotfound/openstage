require "rails_helper"

# robots.txt disallows the chart's filters, ?range=, ?projects= and ?show=,
# for every agent. A crawler that follows them anyway gets a 403 on the stage
# and on a project's page (RefusesFilterCrawls), before any query runs.
RSpec.describe "A crawler on a filter URL", type: :request do
  let(:user) { create(:user, username: "builder", display_name: "Bea") }
  # Meta's crawler, as kamal-proxy logged it on 2026-11-26.
  let(:meta) do
    { "HTTP_USER_AGENT" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 " \
                           "(compatible; meta-externalagent/1.1 (+https://developers.facebook.com/docs/sharing/webmasters/crawler))" }
  end
  let(:browser) { { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15" } }
  let(:link_preview) { { "HTTP_USER_AGENT" => "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)" } }
  let(:filters) { { range: "all", projects: "builder/side.app", show: "commits" } }

  before do
    create(:github_repo, user: user, full_name: "builder/side.app", name: "side.app", homepage: "https://side.example")
    create(:entry, user: user, repo_name: "builder/side.app", title: "Ship the form")
  end

  # Every statement a request runs, the schema's own left out.
  def statements
    seen = []
    counter = ActiveSupport::Notifications.subscribe("sql.active_record") { |event| seen << event.payload[:sql] unless event.payload[:name] == "SCHEMA" }
    yield
    seen
  ensure
    ActiveSupport::Notifications.unsubscribe(counter)
  end

  [ "/builder", "/builder/side.app" ].each do |page|
    describe page do
      it "refuses a crawler each filter, with no body" do
        filters.each do |name, value|
          get page, params: { name => value }, headers: meta

          expect([ name, response.status, response.body ]).to eq([ name, 403, "" ])
        end
      end

      it "refuses a crawler the filters together, as the switches' links carry them" do
        get page, params: filters.merge(page: 2, sort: "name", live: 1), headers: meta

        expect(response).to have_http_status(:forbidden)
      end

      it "gives a crawler the page itself, and the list's pages and sorts" do
        get page, headers: meta
        expect(response).to have_http_status(:ok)

        get page, params: { page: 2, sort: "name" }, headers: meta
        expect(response).to have_http_status(:ok)
      end

      it "gives a person the filtered page" do
        get page, params: filters, headers: browser

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Ship the form")
      end

      it "gives a link preview the filtered page a person shared" do
        get page, params: filters, headers: link_preview

        expect(response).to have_http_status(:ok)
      end

      it "runs no query for a refused request, and records no view" do
        run = statements { get page, params: { range: "all" }, headers: meta }

        expect(run).to eq([])
        expect(ProfileView.count + ProjectView.count).to eq(0)
      end
    end
  end

  it "gives the filtered page to a client that names no agent: no name is no proof of a crawler" do
    get "/builder", params: { range: "all" }

    expect(response).to have_http_status(:ok)
  end

  it "refuses a script by its agent, which the public API is for" do
    get "/builder", params: { range: "all" }, headers: { "HTTP_USER_AGENT" => "python-requests/2.32.3" }

    expect(response).to have_http_status(:forbidden)
  end

  it "refuses the stage's feed with a filter too" do
    get "/builder.rss", params: { range: "all" }, headers: meta

    expect(response).to have_http_status(:forbidden)
  end

  it "leaves the public API to a script, which a bot's agent names too" do
    get "/api/progress/builder", params: { range: "90d" }, headers: { "HTTP_USER_AGENT" => "curl/8.7.1" }

    expect(response).to have_http_status(:ok)
  end
end
