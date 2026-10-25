require "rails_helper"

RSpec.describe "Share cards", type: :request do
  let(:user) { create(:user, username: "builder", display_name: "Bea Builder") }
  let(:avatar) { Vips::Image.black(4, 4).write_to_buffer(".png") }
  # The SVG each card was drawn from, as the request drew it.
  let(:drawn) { [] }

  before do
    allow(Vips::Image).to receive(:svgload_buffer).and_wrap_original do |load, svg|
      drawn << svg
      load.call(svg)
    end
    stub_request(:get, %r{\Ahttps://avatars\.githubusercontent\.com/}).to_return(status: 200, headers: { "Content-Type" => "image/png" }, body: avatar)
  end

  def card_size
    image = Vips::Image.new_from_buffer(response.body, "")
    [ response.media_type, image.width, image.height ]
  end

  def with_projects
    create(:github_repo, user: user, full_name: "builder/app", description: "A tool for builders.", homepage: "https://app.example")
    create(:github_repo, user: user, full_name: "builder/side")
    2.times { |i| create(:entry, user: user, repo_name: "builder/app", occurred_at: (i + 1).days.ago) }
    create(:entry, user: user, repo_name: "builder/side", occurred_at: 3.days.ago)
  end

  describe "a builder's page" do
    before { with_projects }

    it "draws who they are and their projects, each with its commits, as a 1200 by 630 PNG" do
      get "/og/builder"

      expect(response).to have_http_status(:ok)
      expect(card_size).to eq([ "image/png", 1200, 630 ])
      expect(drawn.last).to include("Bea Builder", "@builder · 2 projects", ">app<", ">side<", "Commits per week, last 12 months")
      expect(drawn.last).to include("data:image/png;base64,")
    end

    it "draws the builder's initials when GitHub gives no avatar" do
      stub_request(:get, %r{\Ahttps://avatars\.githubusercontent\.com/}).to_return(status: 404)

      get "/og/builder"

      expect(response).to have_http_status(:ok)
      expect(drawn.last).to include(">BB<")
      expect(drawn.last).not_to include("data:image")
    end

    it "answers 404 for a builder who does not exist" do
      get "/og/nobody"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "a project's page" do
    before { with_projects }

    it "draws what the project is, who builds it, its status and its commits" do
      get "/og/builder/APP"

      expect(response).to have_http_status(:ok)
      expect(card_size).to eq([ "image/png", 1200, 630 ])
      expect(drawn.last).to include(">app<", "Bea Builder", ">Live<", "A tool for builders.", "commits in 12 months")
    end

    it "answers 404 for a name that is no project of theirs" do
      get "/og/builder/nope"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "a blog post" do
    let(:post) { BlogPost.all.find(&:chart) }
    let(:other) { BlogPost.all.reject(&:chart).first }

    it "draws its title, and the line of the project it is about" do
      owner, repo = post.chart.split("/")
      builder = create(:user, username: owner)
      create(:entry, user: builder, repo_name: "#{owner}/#{repo}", occurred_at: 2.days.ago)

      get "/og/blog/#{post.slug}"

      expect(card_size).to eq([ "image/png", 1200, 630 ])
      expect(drawn.last).to include(post.title.split.first(3).join(" "), "#{repo}, commits per week")
    end

    it "draws what a post says when it is about no one project" do
      get "/og/blog/#{other.slug}"

      expect(response).to have_http_status(:ok)
      expect(drawn.last).to include(other.description.split.first(4).join(" "))
    end

    it "answers 404 for a post that does not exist" do
      get "/og/blog/nope"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "every other page" do
    it "draws the landing's headline over the demo page's lines" do
      demo = create(:user, username: "tuxnotfound")
      create(:entry, user: demo, repo_name: "tuxnotfound/openstage", occurred_at: 2.days.ago)

      get "/og"

      expect(card_size).to eq([ "image/png", 1200, 630 ])
      expect(drawn.last).to include(*HomeHelper::TAGLINE, "<polyline")
    end

    it "draws the headline alone without a demo page" do
      get "/og"

      expect(response).to have_http_status(:ok)
      expect(drawn.last).to include(*HomeHelper::TAGLINE)
      expect(drawn.last).not_to include("<polyline")
    end
  end

  it "sends the headline card kept as a file when drawing fails, and reports why" do
    allow(Vips::Image).to receive(:svgload_buffer).and_raise(Vips::Error, "unable to load from buffer")
    allow(Rails.error).to receive(:report)

    get "/og"

    expect(response).to redirect_to("/og-default.png")
    expect(Rails.error).to have_received(:report).with(instance_of(Vips::Error))
  end

  describe "the pages' share tags" do
    def shared
      Nokogiri::HTML(response.body).css("meta[property='og:image'], meta[name='twitter:image']").map { |meta| meta["content"] }.uniq
    end

    it "point a builder's page and a post at their own cards, and the rest at the site's" do
      with_projects
      post = BlogPost.all.first

      get "/builder"
      expect(shared).to eq([ "http://www.example.com/og/builder?v=#{SeoHelper::SHARE_CARD_VERSION}" ])

      get "/blog/#{post.slug}"
      expect(shared).to eq([ "http://www.example.com/og/blog/#{post.slug}?v=#{SeoHelper::SHARE_CARD_VERSION}" ])

      get "/pricing"
      expect(shared).to eq([ "http://www.example.com/og?v=#{SeoHelper::SHARE_CARD_VERSION}" ])
    end
  end
end
