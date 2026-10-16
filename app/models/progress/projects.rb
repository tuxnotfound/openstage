module Progress
  # A builder's projects in order of all-time public commits. The order fixes
  # each project's color, so a project keeps it on every tab and card.
  # Projects with tagged entries and no commits come last.
  class Projects
    # rank: 0 for the project with the most commits.
    Project = Data.define(:repo, :name, :commits, :rank)

    # entries: the builder's public entries, tooling noise left out.
    def initialize(entries)
      @entries = entries
    end

    def all
      @all ||= begin
        counts = @entries.commits.where.not(repo_name: nil).group(:repo_name).count
        repos = counts.sort_by { |repo, n| [ -n, repo ] }.map(&:first)
        repos += (@entries.highlights.where.not(repo_name: nil).distinct.pluck(:repo_name) - repos).sort
        repos.each_with_index.map { |repo, rank| Project.new(repo: repo, name: name_of(repo, repos), commits: counts.fetch(repo, 0), rank: rank) }
      end
    end

    def find(repo)
      all.find { |project| project.repo == repo }
    end

    private

    # The short name, unless two repos share it.
    def name_of(repo, repos)
      short = repo.split("/").last
      repos.count { |other| other.split("/").last == short } > 1 ? repo : short
    end
  end
end
