require "rails_helper"
require Rails.root.join("db/migrate/20261031093035_key_visitor_hashes").to_s

RSpec.describe KeyVisitorHashes, type: :request do
  let!(:user) { create(:user, username: "builder") }
  let(:today) { Date.new(2026, 10, 31) }
  let(:yesterday) { today - 1 }

  def unkeyed(ip, day)
    Digest::SHA256.hexdigest("#{ip}#{day}")
  end

  def counted
    Analytics::CountService.new(user: user).tap(&:call!).counts.slice("visitors", "views")
  end

  def migrate
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  # As the app kept them before the key: two visitors yesterday, one of them
  # twice; that one again today, on the builder's page and a project's; and a
  # view kept with no hash.
  before do
    travel_to Time.utc(2026, 10, 31, 12)
    [ [ "203.0.113.7", yesterday ], [ "203.0.113.7", yesterday ], [ "203.0.113.8", yesterday ], [ "203.0.113.7", today ] ].each do |ip, day|
      create(:profile_view, user: user, viewed_at: day.noon, ip_hash: unkeyed(ip, day))
    end
    create(:profile_view, user: user, viewed_at: today.noon, ip_hash: nil)
    user.project_views.create!(repo_name: "builder/app", viewed_at: today.noon, ip_hash: unkeyed("203.0.113.7", today))
  end

  it "keys every hash as VisitorHash makes them, a batch at a time, and keeps every day's visitors and views" do
    stub_const("KeyVisitorHashes::BATCH", 2)
    counts = counted

    migrate

    expect(counted).to eq(counts)
    expect(user.profile_views.order(:id).pluck(:ip_hash)).to eq(
      [ VisitorHash.of("203.0.113.7", yesterday) ] * 2 + [ VisitorHash.of("203.0.113.8", yesterday), VisitorHash.of("203.0.113.7", today), nil ]
    )
    expect(user.project_views.pluck(:ip_hash)).to eq([ VisitorHash.of("203.0.113.7", today) ])
  end

  it "leaves a row matching the next view by the same visitor on the same day" do
    migrate
    counts = counted

    get "/builder", headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (Macintosh) Safari/605.1.15", "REMOTE_ADDR" => "203.0.113.7" }

    expect(counted["visitors"]).to eq(counts["visitors"])
    expect(counted["views"]["page"][today]).to eq(counts["views"]["page"][today] + 1)
  end

  it "stops a rollback, as a second up would key every hash twice" do
    expect { ActiveRecord::Migration.suppress_messages { described_class.new.migrate(:down) } }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
