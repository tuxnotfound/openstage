# A builder with many projects, beside the heavy builder of seed.rb: 135
# public repos, 102 of them with commits, about 5,400 commits in a year. The
# shape of the stage that answered in 2.35 s in production on 2026-11-24,
# against 0.39 s for a stage of seven projects. It ends on ANALYZE: measured
# before the database counts the new rows, each read of the entries plans
# as if the builder had a handful and runs about five times slower (76 ms
# against 14 ms to rank the projects, 2026-11-26).
#   DATABASE_URL=postgres:///openstage_perf bin/rails runner script/perf/many.rb
#   DATABASE_URL=postgres:///openstage_perf bin/rails runner script/perf/measure.rb /many /many?page=2 /api/progress/many
abort "Refusing: run this on a scratch database whose name contains 'perf'." unless ActiveRecord::Base.connection.current_database.include?("perf")
abort "The builder 'many' is already there." if User.exists?(username: "many")

srand(7)
now = Time.current
many = User.create!(github_uid: "perf-many", github_username: "many", username: "many", display_name: "Many Projects", time_zone: "Europe/Lisbon",
                    avatar_url: "https://avatars.githubusercontent.com/u/1")
repos = (1..135).map { |i| "many/repo-#{i}" }
repos.each_with_index do |repo, i|
  GithubRepo.create!(user: many, github_repo_id: 70_000 + i, name: repo.split("/").last, full_name: repo, description: "Project #{i + 1}",
                     homepage: (i < 20 ? "https://m#{i}.example" : nil))
end

rows = (0...5_400).map do |k|
  at = now - rand(0..364).days - rand(0..86_000).seconds
  { user_id: many.id, entry_type: "shipped", source: "github", title: "Commit #{k}", occurred_at: at, repo_name: repos[k % 102],
    external_id: "many-sha-#{k}", url: nil, visibility: "public", hidden: false, created_at: at, updated_at: at }
end
rows += (0...40).map do |i|
  at = now - rand(0..364).days
  { user_id: many.id, entry_type: %w[milestone shipped note].sample, source: "manual", title: "Update #{i}", occurred_at: at, repo_name: repos[i % 30],
    external_id: nil, url: nil, visibility: "public", hidden: false, created_at: at, updated_at: at }
end
rows.each_slice(10_000) { |slice| Entry.insert_all!(slice) }

Analytics::RollUpService.new(user: many).call!
ActiveRecord::Base.connection.execute("ANALYZE entries; ANALYZE github_repos")
puts "many: #{many.github_repos.count} repos, #{many.entries.count} entries, id #{many.id}"
