require "rails_helper"

# Production answers an error through the exceptions app
# (config/application.rb); tests show the debug page instead, so these turn
# production's handling on.
RSpec.describe "Error pages", type: :request do
  around do |example|
    env_config = Rails.application.env_config
    saved = env_config.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
    env_config.merge!("action_dispatch.show_exceptions" => :all, "action_dispatch.show_detailed_exceptions" => false)
    example.run
  ensure
    env_config.merge!(saved)
  end

  it "answers a path no route matches with the site's 404 page" do
    get "/a/b/c", headers: { "Accept" => "text/html" }

    expect(response).to have_http_status(:not_found)
    page = Nokogiri::HTML(response.body)
    expect(page.at_css("h1").text).to eq("This page doesn't exist")
    expect(page.at_css("main a[href='/feed']")).to be_present
  end

  it "answers anything but a page with the bare status" do
    get "/a/b/c", headers: { "Accept" => "application/json" }

    expect(response).to have_http_status(:not_found)
    expect(response.body).to be_empty
  end

  it "keeps the static page for every other error" do
    allow(BlogPost).to receive(:all).and_raise("boom")

    get "/blog", headers: { "Accept" => "text/html" }

    expect(response).to have_http_status(:internal_server_error)
    expect(response.body).to eq(Rails.public_path.join("500.html").read)
  end
end
