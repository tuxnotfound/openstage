module GithubCommits
  # Reads the lines each recent commit added and removed, and the languages
  # they were in, so the week card can show how much code moved. A batch per
  # run, newest first; the rest wait for the next sync.
  class FetchStatsService < ApplicationService
    WINDOW = 8.weeks
    BATCH = 200
    LANGUAGES = {
      "rb" => "Ruby", "rake" => "Ruby", "gemspec" => "Ruby", "erb" => "ERB", "js" => "JavaScript", "mjs" => "JavaScript",
      "jsx" => "JavaScript", "ts" => "TypeScript", "tsx" => "TypeScript", "html" => "HTML", "css" => "CSS", "scss" => "SCSS",
      "py" => "Python", "go" => "Go", "rs" => "Rust", "swift" => "Swift", "kt" => "Kotlin", "java" => "Java", "php" => "PHP",
      "ex" => "Elixir", "exs" => "Elixir", "sh" => "Shell", "dart" => "Dart", "vue" => "Vue", "svelte" => "Svelte",
      "c" => "C", "h" => "C", "cpp" => "C++", "cc" => "C++", "hpp" => "C++", "cs" => "C#", "sql" => "SQL", "md" => "Markdown"
    }.freeze
    NAMED = { "Gemfile" => "Ruby", "Rakefile" => "Ruby" }.freeze
    # Files tools write, not people. A lockfile update would drown the week.
    GENERATED = %r{
      (\A|/)(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|Gemfile\.lock|Cargo\.lock|composer\.lock|poetry\.lock|go\.sum)\z
      | (\A|/)(vendor|node_modules|dist|build)/
      | \.min\.(js|css)\z
    }x

    # tokens: a GithubExtras::Tokens for this user.
    attr_accessor :user, :tokens
    attr_reader :fetched

    validates :user, :tokens, presence: true

    private

    def execute
      @fetched = 0
      repos = user.github_repos.index_by(&:full_name)
      pending.each do |entry|
        record(entry, GithubGateway.commit_files(entry.repo_name, entry.external_id, token: tokens.for(repos[entry.repo_name])))
      rescue ApplicationGateway::Unauthorized, ApplicationGateway::RateLimited
        # Out of calls, or the token lost access. The next sync carries on.
        break
      rescue ApplicationGateway::ClientError
        # Gone from GitHub (force-pushed away, repo deleted): nothing to count.
        entry.update!(stats_fetched_at: Time.current)
      end
    end

    def pending
      user.entries.listed.where(source: :github, entry_type: :shipped, stats_fetched_at: nil, occurred_at: WINDOW.ago..)
          .where(repo_name: user.github_repos.included_repos.select(:full_name)).where.not(external_id: nil)
          .order(occurred_at: :desc).limit(BATCH)
    end

    def record(entry, files)
      counted = files.reject { |file| GENERATED.match?(file.filename) }
      entry.update!(additions: counted.sum(&:additions), deletions: counted.sum(&:deletions), files_changed: counted.size,
                    languages: languages(counted), stats_fetched_at: Time.current)
      @fetched += 1
    end

    # Lines changed per language, by file extension.
    def languages(files)
      files.each_with_object(Hash.new(0)) do |file, lines|
        name = File.basename(file.filename)
        language = NAMED[name] || LANGUAGES[File.extname(name).delete_prefix(".").downcase]
        lines[language] += file.additions + file.deletions if language
      end
    end
  end
end
