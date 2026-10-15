require "rails_helper"

RSpec.describe Progress::Projects do
  let(:user) { create(:user) }

  def projects
    described_class.new(user.entries.publicly_visible.without_tooling_noise)
  end

  it "ranks repos by all-time commits, then tagged-only repos by name" do
    2.times { create(:entry, user: user, repo_name: "me/b") }
    create(:entry, user: user, repo_name: "me/a")
    create(:entry, user: user, source: "manual", entry_type: "milestone", repo_name: "me/z")

    expect(projects.all.map { |project| [ project.name, project.commits, project.rank ] }).to eq([ [ "b", 2, 0 ], [ "a", 1, 1 ], [ "z", 0, 2 ] ])
  end

  it "keeps the owner in the name when two repos share one" do
    create(:entry, user: user, repo_name: "me/app")
    create(:entry, user: user, repo_name: "team/app")
    create(:entry, user: user, repo_name: "me/site")

    expect(projects.all.map(&:name)).to eq(%w[me/app site team/app])
    expect(projects.find("me/site").name).to eq("site")
  end
end
