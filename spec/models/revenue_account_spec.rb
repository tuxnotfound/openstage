require "rails_helper"

RSpec.describe RevenueAccount do
  let(:user) { create(:user) }

  it "keeps the key encrypted, so the database never holds it as it is" do
    account = user.revenue_accounts.create!(provider: "stripe", api_key: "rk_live_abc123")

    stored = described_class.connection.select_value("SELECT api_key FROM revenue_accounts WHERE id = #{account.id}")
    expect(stored).not_to include("rk_live_abc123")
    expect(account.reload.api_key).to eq("rk_live_abc123")
  end

  it "names the key by its last four characters" do
    expect(described_class.new(api_key: "rk_live_abc123").key_ending).to eq("c123")
  end

  it "takes one account per provider, and only the ones Openstage reads" do
    user.revenue_accounts.create!(provider: "stripe", api_key: "rk_live_a")

    expect(user.revenue_accounts.new(provider: "stripe", api_key: "rk_live_b")).not_to be_valid
    expect(user.revenue_accounts.new(provider: "paddle", api_key: "pdl_a")).not_to be_valid
  end
end
