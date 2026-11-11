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

    it "keeps every post's title within the 60 characters search shows, its headline whole" do
      BlogPost.all.each do |post|
        get "/blog/#{post.slug}"

        page = Nokogiri::HTML(response.body)
        expect(page.at_css("title").text.length).to be <= 60, post.slug
        expect(page.at_css("h1").text.squish).to eq(post.title)
      end
    end

    it "returns 404 for an unknown slug, on the site's 404 page" do
      get "/blog/does-not-exist"

      expect(response).to have_http_status(:not_found)
      expect(Nokogiri::HTML(response.body).at_css("h1").text).to eq("This page doesn't exist")
    end
  end
end
