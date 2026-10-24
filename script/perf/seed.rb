# A heavy builder for performance measurements: three years, 10 projects,
# about 27,000 commits and 350,000 page views, among 50 other builders.
# Writes thousands of rows, so it runs only on a database named for it:
#   DATABASE_URL=postgres:///openstage_perf bin/rails db:create db:schema:load
#   DATABASE_URL=postgres:///openstage_perf bin/rails runner script/perf/seed.rb
abort "Refusing: run this on a scratch database whose name contains 'perf'." unless ActiveRecord::Base.connection.current_database.include?("perf")

srand(42)
now = Time.current
heavy = User.create!(github_uid: "perf1", github_username: "heavy", username: "heavy", display_name: "Heavy Builder", pro: true, time_zone: "Europe/Lisbon", avatar_url: "https://avatars.githubusercontent.com/u/1?v=4")
repos = (1..10).map { |i| "heavy/project-#{i}" }
repos.each_with_index { |repo, i| GithubRepo.create!(user: heavy, github_repo_id: 50_000 + i, name: repo.split("/").last, full_name: repo, homepage: (i < 3 ? "https://p#{i}.example" : nil)) }

def batches(rows, model)
  rows.each_slice(10_000) { |slice| model.insert_all!(slice) }
end

rows = []
(0...1095).each do |back|
  day = now - back.days
  (rand(0..50)).times do |k|
    at = day.change(hour: rand(0..23), min: rand(0..59))
    rows << { user_id: heavy.id, entry_type: "shipped", source: "github", title: "Commit #{back}-#{k}", occurred_at: at, repo_name: repos[(k + back / 90) % 10], external_id: "sha-#{back}-#{k}", url: nil, created_at: at, updated_at: at }
  end
end
300.times do |i|
  at = now - rand(0..1094).days
  rows << { user_id: heavy.id, entry_type: %w[milestone posted note].sample, source: "manual", title: "Update #{i}", occurred_at: at, repo_name: [ nil, *repos ].sample, url: (i.even? ? "https://example.com/#{i}" : nil), external_id: "m-#{i}", created_at: at, updated_at: at }
end
batches(rows, Entry)
puts "heavy entries: #{Entry.where(user: heavy).count}"

others = (1..50).map { |i| User.create!(github_uid: "o#{i}", github_username: "other#{i}", username: "other#{i}", display_name: "Other #{i}") }
others.each do |user|
  batches((0...2000).map { |k| at = now - rand(0..700).days; { user_id: user.id, entry_type: "shipped", source: "github", title: "c#{k}", occurred_at: at, repo_name: "other/r#{k % 4}", external_id: "x#{k}", created_at: at, updated_at: at } }, Entry)
end

hosts = [ "news.ycombinator.com", "x.com", "github.com", nil, "www.google.com", "bsky.app", "reddit.com", "linkedin.com" ]
countries = %w[US US US DE GB PT IN FR BR CA NL ES IT JP AU PL SE]
views = (0...200_000).map { |i| at = now - rand(0..364).days - rand(0..86_000).seconds; { user_id: heavy.id, viewed_at: at, referrer: hosts.sample, ip_hash: "h#{i % 40_000}", country: countries.sample, created_at: at, updated_at: at } }
batches(views, ProfileView)
pviews = (0...150_000).map { |i| at = now - rand(0..364).days - rand(0..86_000).seconds; { user_id: heavy.id, repo_name: repos.sample, viewed_at: at, referrer: hosts.sample, ip_hash: "p#{i % 30_000}", country: countries.sample, created_at: at, updated_at: at } }
batches(pviews, ProjectView)
linked = Entry.where(user: heavy).where.not(url: nil).limit(50).pluck(:id)
batches((0...5000).map { |i| at = now - rand(0..364).days; { user_id: heavy.id, entry_id: linked.sample, ip_hash: "c#{i}", clicked_at: at, created_at: at, updated_at: at } }, EntryClick)
batches((0...3000).map { |i| at = now - rand(0..364).days; { user_id: heavy.id, repo_name: repos.first(3).sample, kind: %w[visit github].sample, ip_hash: "k#{i}", clicked_at: at, created_at: at, updated_at: at } }, ProjectClick)
batches((0...20_000).map { |i| at = now - rand(0..364).days; { user_id: heavy.id, kind: %w[badge embed].sample, viewed_at: at, referrer: "site#{i % 40}.example", ip_hash: "b#{i}", created_at: at, updated_at: at } }, BadgeImpression)
200.times { |i| heavy.subscriptions.create!(email: "s#{i}@example.com", confirmed_at: now - rand(0..364).days, github_repo: (GithubRepo.where(user: heavy).sample if i.odd?)) }
puts "views #{ProfileView.count} project views #{ProjectView.count} entries #{Entry.count} heavy id #{heavy.id}"
