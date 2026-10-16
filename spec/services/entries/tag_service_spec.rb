require "rails_helper"

RSpec.describe Entries::TagService do
  let(:entry) { create(:entry, source: "twitter", entry_type: "posted", repo_name: nil) }

  it "puts the entry in a project" do
    described_class.new(entry: entry, repo_name: "me/app").call!

    expect(entry.reload).to have_attributes(repo_name: "me/app", no_project: false)
  end

  it "marks the entry as having no project" do
    entry.update!(repo_name: "me/app")
    described_class.new(entry: entry, no_project: true).call!

    expect(entry.reload).to have_attributes(repo_name: nil, no_project: true)
  end

  it "refuses without a project or the no-project answer" do
    service = described_class.new(entry: entry, repo_name: "")

    expect(service.call).to be(false)
    expect(service.errors[:repo_name]).to be_present
  end

  it "refuses without an entry" do
    expect(described_class.new(repo_name: "me/app").call).to be(false)
  end
end
