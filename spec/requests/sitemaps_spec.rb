require "rails_helper"

RSpec.describe "Sitemaps", type: :request do
  describe "GET /sitemap.xml" do
    it "returns xml sitemap with the homepage and public profiles" do
      user = create(:user, username: "builder")
      create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: 2.days.ago)

      get "/sitemap.xml"

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/xml")
      expect(response.body).to include(root_url)
      expect(response.body).to include(profile_url("builder"))
      expect(response.body).to include("<urlset")
    end

    it "includes the marketing pages and blog posts" do
      get "/sitemap.xml"

      expect(response.body).to include(pricing_url)
      expect(response.body).to include(about_url)
      expect(response.body).to include(blog_url)
      expect(response.body).to include(blog_post_url(BlogPost.all.first))
    end

    it "dates no page from the commits a builder hides, and still lists the project's page" do
      user = create(:user, username: "builder")
      create(:entry, user: user, entry_type: "note", source: "manual", occurred_at: Time.utc(2026, 1, 5, 9))
      create(:entry, user: user, repo_name: "builder/app", occurred_at: Time.utc(2026, 2, 6, 9))
      create(:entry, user: user, repo_name: "builder/site", occurred_at: Time.utc(2026, 1, 7, 9))
      create(:github_repo, user: user, full_name: "builder/app", hidden_numbers: [ "commits" ])

      get "/sitemap.xml"

      urls = Nokogiri::XML(response.body).remove_namespaces!.css("url").to_h { |url| [ url.at_css("loc").text, url.at_css("lastmod")&.text ] }
      expect(urls.values_at(profile_url("builder"), project_page_url("builder", "app"), project_page_url("builder", "site")))
        .to eq([ "2026-01-07T09:00:00Z", nil, "2026-01-07T09:00:00Z" ])
      expect(response.body).not_to include("2026-02-06")
    end

    it "does not include deleted users" do
      create(:user, username: "deleted_builder", deleted_at: Time.current)

      get "/sitemap.xml"

      expect(response.body).not_to include(profile_url("deleted_builder"))
    end
  end
end
