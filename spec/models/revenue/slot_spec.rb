require "rails_helper"

RSpec.describe Revenue::Slot do
  let(:user) { create(:user, pro: false) }
  let(:shipnote) { create(:github_repo, user: user, name: "shipnote", revenue_set_up_at: Time.utc(2026, 11, 7, 9)) }
  let(:tidepool) { create(:github_repo, user: user, name: "tidepool", revenue_set_up_at: Time.utc(2026, 11, 7, 10)) }

  it "is held on Free by the project first given a product" do
    shipnote
    tidepool

    expect(described_class.new(user).repo).to eq(shipnote)
    expect(described_class.new(user).instead_of(tidepool)).to eq(shipnote)
    expect(described_class.new(user).instead_of(shipnote)).to be_nil
  end

  it "is free for any project before one is set up" do
    expect(described_class.new(user).instead_of(create(:github_repo, user: user))).to be_nil
  end

  it "never stands in the way on Pro" do
    shipnote
    user.update!(pro: true)

    expect(described_class.new(user).instead_of(tidepool)).to be_nil
  end
end
