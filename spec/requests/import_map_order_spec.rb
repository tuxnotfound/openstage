require "rails_helper"

# Firefox ignores an import map once a module has started loading, from a
# script before it or from the Link header, and then nothing imported through
# it runs: no controller, no Turbo, no view count.
RSpec.describe "The import map's place in a page's head", type: :request do
  let(:user) { create(:user, username: "builder") }
  let!(:repo) { create(:github_repo, user: user, name: "shipnote", full_name: "builder/shipnote") }

  before { create(:entry, user: user, repo_name: repo.full_name, occurred_at: 1.day.ago) }

  def scripts
    Nokogiri::HTML(response.body).css("head script[type='importmap'], head script[type='module']")
  end

  it "comes before the charts' bundle on a stage, a project's page and the dashboard, and the Link header leaves the bundle out" do
    sign_in_as(user)

    [ "/builder", "/builder/shipnote", "/dashboard" ].each do |path|
      get path

      expect(scripts.first["type"]).to eq("importmap"), path
      expect(scripts.map { |script| script["src"].to_s }).to include(a_string_matching(%r{/assets/charts-})), path
      expect(response.headers["Link"].to_s).not_to include("charts-"), path
    end
  end
end
