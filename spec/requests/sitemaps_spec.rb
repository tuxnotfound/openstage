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

    it "does not include deleted users" do
      create(:user, username: "deleted_builder", deleted_at: Time.current)

      get "/sitemap.xml"

      expect(response.body).not_to include(profile_url("deleted_builder"))
    end
  end
end