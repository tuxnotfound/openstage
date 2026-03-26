require "rails_helper"

RSpec.describe Entry, type: :model do
  let(:user) { create(:user) }

  describe "validations" do
    subject { build(:entry, user: user) }

    it { should belong_to(:user) }
    it { should validate_presence_of(:entry_type) }
    it { should validate_presence_of(:source) }
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:occurred_at) }
  end

  describe "external_id uniqueness" do
    it "prevents duplicate entries for the same user and external_id" do
      create(:entry, user: user, external_id: "abc123")
      duplicate = build(:entry, user: user, external_id: "abc123")
      expect(duplicate).not_to be_valid
    end

    it "allows the same external_id for different users" do
      other_user = create(:user)
      create(:entry, user: user, external_id: "abc123")
      entry = build(:entry, user: other_user, external_id: "abc123")
      expect(entry).to be_valid
    end

    it "allows multiple entries with nil external_id for the same user" do
      create(:entry, user: user, external_id: nil)
      entry = build(:entry, user: user, external_id: nil)
      expect(entry).to be_valid
    end
  end

  describe "scopes" do
    it "visible excludes hidden entries" do
      create(:entry, user: user, hidden: false)
      create(:entry, user: user, hidden: true)
      expect(Entry.visible.count).to eq(1)
    end

    it "chronological orders by occurred_at descending" do
      older = create(:entry, user: user, occurred_at: 2.days.ago)
      newer = create(:entry, user: user, occurred_at: 1.day.ago)
      expect(Entry.chronological.to_a).to eq([ newer, older ])
    end
  end
end
