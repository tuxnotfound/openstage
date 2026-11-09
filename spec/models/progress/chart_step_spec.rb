require "rails_helper"

RSpec.describe Progress::ChartStep do
  let(:user) { create(:user, pro: true) }
  let!(:repo) { create(:github_repo, user: user, full_name: "#{user.username}/app", name: "app") }

  def counted
    create(:entry, user: user, repo_name: repo.full_name)
  end

  it "asks for repos while no repo has anything" do
    expect(described_class.new(user).key).to eq(:repos)
  end

  it "asks for a website once commits count" do
    counted

    expect(described_class.new(user).key).to eq(:site)
    expect(described_class.new(user, repo: repo).key).to eq(:site)
  end

  it "looks at the one project of a project's page" do
    counted
    other = create(:github_repo, user: user, full_name: "#{user.username}/other", name: "other", site_set_up_at: 1.day.ago)
    create(:entry, user: user, repo_name: other.full_name)

    expect(described_class.new(user, repo: repo).key).to eq(:site)
    expect(described_class.new(user).key).to eq(:stripe)
  end

  it "asks for Stripe once a website is set up, and for nothing once it is connected" do
    counted
    repo.update!(site_set_up_at: 1.day.ago)
    expect(described_class.new(user).key).to eq(:stripe)

    user.revenue_accounts.create!(provider: "stripe", api_key: "rk_test_ok")
    expect(described_class.new(user).key).to be_nil
  end

  it "points at the switches when nothing shows because its builder hides it" do
    counted
    repo.update!(hidden_numbers: %w[commits])

    expect(described_class.new(user, repo: repo, nothing_shown: true).key).to eq(:hidden)
    expect(described_class.new(user, repo: repo, nothing_shown: false).key).to eq(:site)
  end

  it "asks Free for nothing where Pro would connect Stripe, since Free's MRR never draws on a chart" do
    user.update!(pro: false)
    counted
    repo.update!(site_set_up_at: 1.day.ago)

    expect(described_class.new(user).key).to be_nil
  end
end
