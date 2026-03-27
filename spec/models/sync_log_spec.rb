require "rails_helper"

RSpec.describe SyncLog, type: :model do
  let(:user) { create(:user) }

  describe "associations" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    subject { build(:sync_log, user: user) }

    it { is_expected.to validate_presence_of(:source) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:ran_at) }
  end

  describe "enums" do
    it "has github and twitter sources" do
      expect(described_class.sources.keys).to contain_exactly("github", "twitter")
    end

    it "has running, success, and failed statuses" do
      expect(described_class.statuses.keys).to contain_exactly("running", "success", "failed")
    end
  end
end
