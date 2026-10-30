module Progress
  # A builder's projects in order of all-time public commits. The order fixes
  # each project's color, so a project keeps it on every tab and card.
  # Projects with tagged entries and no commits come last. The reads that rank
  # them also say when each project's commits and entries began, so a page
  # that needs those too, for where its chart starts (TallyService,
  # CountService), does not read the builder's history again.
  class Projects
    # Below this many public commits a project's page stays out of search:
    # the sitemap leaves it out and the page says noindex. A page with a
    # commit or two reads as thin, and Google holds thin pages against the
    # rest of the site. It goes in once the project fills.
    INDEXED_COMMITS = 10

    # rank: 0 for the project with the most commits.
    Project = Data.define(:repo, :name, :commits, :rank) do
      def indexed?
        commits >= INDEXED_COMMITS
      end
    end

    # entries: the builder's public entries, tooling noise left out.
    def initialize(entries)
      @entries = entries
    end

    def all
      @all ||= begin
        counts = commits.filter_map { |repo, count| [ repo, count ] if repo }.to_h
        repos = counts.sort_by { |repo, n| [ -n, repo ] }.map(&:first)
        repos += (first_highlights.keys.compact - repos).sort
        repos.each_with_index.map { |repo, rank| Project.new(repo: repo, name: name_of(repo, repos), commits: counts.fetch(repo, 0), rank: rank) }
      end
    end

    def find(repo)
      all.find { |project| project.repo == repo }
    end

    # The time of each project's first commit, ever, by repo, the commits
    # with no project under nil. shown: only the projects that show their
    # commits to visitors (GithubRepo#hidden_numbers).
    def first_commits(shown: false)
      commits.to_h { |repo, _count, first, first_shown| [ repo, shown ? first_shown : first ] }.compact
    end

    # The time of each project's first shipped or published entry, ever, the
    # entries with no project under nil.
    def first_highlights
      @first_highlights ||= @entries.highlights.group(:repo_name).minimum(:occurred_at)
    end

    private

    # [repo, commits, first commit, first commit visitors see] per repo.
    def commits
      @commits ||= @entries.commits.group(:repo_name).pluck(:repo_name, Arel.sql("COUNT(*)"), Arel.sql("MIN(entries.occurred_at)"),
                                                            Arel.sql("MIN(entries.occurred_at) FILTER (WHERE #{Entry::HIDDEN_COMMITS_SQL})"))
    end

    # The short name, unless two repos share it.
    def name_of(repo, repos)
      short = repo.split("/").last
      repos.count { |other| other.split("/").last == short } > 1 ? repo : short
    end
  end
end
