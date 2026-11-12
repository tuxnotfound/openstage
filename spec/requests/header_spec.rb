require "rails_helper"

RSpec.describe "The header", type: :request do
  let(:browser) { { "HTTP_USER_AGENT" => "Mozilla/5.0 (iPhone) Safari/605.1.15" } }

  def header
    Nokogiri::HTML(response.body).at_css("body > header")
  end

  def form_of(words)
    header.css("form").find { |form| form.text.squish == words }
  end

  it "offers a visitor their own stage, straight to GitHub's sign-in, and Sign in beside the links, on every page" do
    create(:user, username: "builder")

    [ "/", "/builder", "/pricing" ].each do |path|
      get path
      expect([ form_of("Make your own stage")&.[]("action"), form_of("Sign in")&.[]("action") ]).to eq([ "/auth/github", "/auth/github" ])
    end
    expect(form_of("Make your own stage").at_css("button")["class"]).to eq("os-btn sm")
    expect(header.text).not_to include("with GitHub")
  end

  it "keeps the logo and the button on a phone, and folds the links and the theme into a menu beside them" do
    get "/"

    expect(header.at_css("nav")["class"]).to include("max-sm:hidden")
    expect(header.at_css("[data-controller='theme']").parent["class"]).to eq("max-sm:hidden")
    expect(form_of("Make your own stage")["class"]).to eq("max-sm:ml-auto")
    expect(header.at_css("nav").text.squish).to eq("Feed Pricing Blog Sign in")

    menu = header.at_css("details[data-phone-menu]")
    expect(menu["class"]).to include("sm:hidden")
    expect(menu.at_css("summary")["aria-label"]).to eq("Menu")
    expect(menu.css("nav a").map { |link| [ link.text, link["href"] ] }).to eq([ %w[Feed /feed], %w[Pricing /pricing], %w[Blog /blog] ])
    expect(menu.at_css("form[action='/auth/github']").text.squish).to eq("Sign in")
    expect(menu.at_css("[data-controller='theme']")).to be_present
  end

  it "stays as it was for a member" do
    sign_in_as(create(:user))
    get "/feed"

    expect(header.text).to include("Dashboard", "Your stage")
    expect(header.text).not_to include("Make your own stage", "Sign in")
  end

  it "counts each start by the tag the visitor came with, and none of a member reconnecting" do
    get "/", params: { ref: "reddit" }, headers: browser
    post "/auth/github", headers: browser

    expect(Event.named("sign_in_start").pluck(:detail)).to eq([ "reddit" ])
    expect(response).to redirect_to("/auth/github/callback")
  end

  it "counts a start from the stage's footer under footer, unless the visitor came with a tag" do
    post "/auth/github", params: { ref: "footer" }, headers: browser
    expect(Event.named("sign_in_start").pluck(:detail)).to eq([ "footer" ])

    reset!
    get "/", params: { ref: "x" }, headers: browser
    post "/auth/github", params: { ref: "footer" }, headers: browser
    expect(Event.named("sign_in_start").pluck(:detail)).to eq(%w[footer x])
  end
end
