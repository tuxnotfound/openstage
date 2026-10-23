# The founder's public page on 2026-10-14 (doc/progress/data.json), seeded as
# a builder's entries for the progress specs. Every row lands at noon UTC, so
# the days match the design round's. Each logged entry keeps its id from the
# file as external_id "progress-<id>".
module ProgressData
  DATA = JSON.parse(Rails.root.join("doc/progress/data.json").read)
  TODAY = Time.utc(2026, 10, 15, 12)

  def seed_progress_data(user)
    Entry.insert_all!(progress_commit_rows(user))
    Entry.insert_all!(progress_entry_rows(user))
  end

  def progress_entry(user, id)
    user.entries.find_by!(external_id: "progress-#{id}")
  end

  def progress_repo(index)
    "tuxnotfound/#{DATA['projects'].fetch(index)}"
  end

  # The file's commits from one day to another, of some projects or all, so a
  # spec's expectation comes from the data and not from the page.
  def progress_commits(days, indexes = nil)
    DATA["days"].sum do |day, counts|
      next 0 unless days.cover?(Date.parse(day))

      counts.sum { |index, n| indexes.nil? || indexes.include?(index) ? n : 0 }
    end
  end

  # The file's entries with no project from one day to another.
  def progress_untagged(days)
    DATA["entries"].count { |entry| entry["r"].nil? && days.cover?(Date.parse(entry["d"])) }
  end

  private

  def progress_commit_rows(user)
    DATA["days"].flat_map do |day, counts|
      counts.flat_map do |index, n|
        Array.new(n) do |k|
          { user_id: user.id, source: "github", entry_type: "shipped", title: "Commit #{k + 1}",
            repo_name: progress_repo(index), occurred_at: "#{day} 12:00:00 UTC" }
        end
      end
    end
  end

  def progress_entry_rows(user)
    DATA["entries"].map do |entry|
      { user_id: user.id, source: "manual", entry_type: entry["k"] == "s" ? "milestone" : "posted",
        title: entry["t"], body: entry["b"], pinned: entry["pin"] == 1, external_id: "progress-#{entry['id']}",
        repo_name: entry["r"] && progress_repo(entry["r"]), occurred_at: "#{entry['d']} 12:00:00 UTC" }
    end
  end
end
