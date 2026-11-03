require "rails_helper"

RSpec.describe "Openstage's own visits", type: :request do
  let(:builder) { create(:user, username: "tux") }

  before { create(:github_repo, user: builder, full_name: "tux/openstage", name: "openstage", site_token: "os_own") }

  def counter
    Nokogiri::HTML(response.body).at_css("head script[src='/v.js']")
  end

  it "loads no counter of its own while its project's token is unset" do
    get "/"
    expect(counter).to be_nil
  end

  describe "with its project's token set" do
    around do |example|
      ENV["OPENSTAGE_PROJECT_TOKEN"] = "os_own"
      example.run
    ensure
      ENV.delete("OPENSTAGE_PROJECT_TOKEN")
    end

    it "counts this site with its own script, for visitors and for other builders" do
      get "/"
      expect(counter.to_h).to include("defer" => "defer", "data-project" => "os_own")

      sign_in_as(create(:user, username: "ada"))
      get "/dashboard"
      expect(counter["data-project"]).to eq("os_own")
    end

    it "leaves out the visits of its project's own builder" do
      sign_in_as(builder)
      get "/dashboard"
      expect(counter).to be_nil
    end
  end
end
