require "rails_helper"

RSpec.describe Entries::DeleteService do
  let(:user) { create(:user) }

  it "deletes a commit and remembers its SHA" do
    entry = create(:entry, user: user, source: "github", external_id: "abc123")

    expect(described_class.new(entry: entry).call).to be(true)

    expect(Entry.exists?(entry.id)).to be(false)
    expect(DismissedCommit.where(user: user).pluck(:sha)).to eq([ "abc123" ])
  end

  # A commit deleted, re-imported by an older build, and deleted again.
  it "deletes a commit whose SHA is already remembered" do
    DismissedCommit.create!(user: user, sha: "abc123")
    entry = create(:entry, user: user, source: "github", external_id: "abc123")

    expect(described_class.new(entry: entry).call).to be(true)
    expect(DismissedCommit.where(user: user).count).to eq(1)
  end

  it "deletes a note without remembering anything" do
    note = create(:entry, user: user, source: "manual", entry_type: "note")

    described_class.new(entry: note).call!

    expect(Entry.exists?(note.id)).to be(false)
    expect(DismissedCommit.count).to eq(0)
  end

  it "goes with the user" do
    described_class.new(entry: create(:entry, user: user, source: "github", external_id: "abc123")).call!

    user.destroy!

    expect(DismissedCommit.count).to eq(0)
  end

  it "requires an entry" do
    expect(described_class.new(entry: nil).call).to be(false)
  end
end
