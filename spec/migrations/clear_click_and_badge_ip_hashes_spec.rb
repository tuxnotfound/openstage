require "rails_helper"
require Rails.root.join("db/migrate/20261031093034_clear_click_and_badge_ip_hashes").to_s

RSpec.describe ClearClickAndBadgeIpHashes do
  let(:tables) { %w[entry_clicks project_clicks badge_impressions] }

  def stored(table)
    ActiveRecord::Base.connection.select_values("SELECT ip_hash FROM #{table} ORDER BY id")
  end

  it "clears the visitor's hash of every click and every badge or embed view, and keeps the rows" do
    user = create(:user)
    create(:entry_click, user: user, entry: create(:entry, user: user, url: "https://example.com/post"))
    user.project_clicks.create!(repo_name: "me/app", kind: "visit", clicked_at: Time.current)
    create(:badge_impression, user: user)
    create(:badge_impression, user: user, kind: "embed")
    tables.each { |table| ActiveRecord::Base.connection.execute("UPDATE #{table} SET ip_hash = md5(id::text)") }

    ActiveRecord::Migration.suppress_messages { described_class.new.up }

    expect(tables.map { |table| stored(table) }).to eq([ [ nil ], [ nil ], [ nil, nil ] ])
  end

  it "stops a rollback, as the hashes cannot come back" do
    expect { ActiveRecord::Migration.suppress_messages { described_class.new.migrate(:down) } }.to raise_error(ActiveRecord::IrreversibleMigration)
  end
end
