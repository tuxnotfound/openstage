require "rails_helper"

RSpec.describe "Blog", type: :request do
  describe "GET /blog" do
    it "lists published posts" do
      get "/blog"

      expect(response).to have_http_status(:ok)
      BlogPost.all.each do |post|
        expect(response.body).to include(post.title)
      end
    end
  end

  describe "GET /blog/:slug" do
    it "renders an existing post with article structured data" do
      post = BlogPost.all.first

      get "/blog/#{post.slug}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(post.title)
      expect(response.body).to include('"@type":"BlogPosting"')
    end

    it "returns 404 for an unknown slug" do
      get "/blog/does-not-exist"

      expect(response).to have_http_status(:not_found)
    end
  end
end
