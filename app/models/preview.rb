# A GitHub user's stage as a visitor sees it before signing in
# (Previews::BuildService): who they are, their projects ranked by commits
# over the last 12 months, the chart of those months (Preview::Section), a
# card per project with a colour and their latest commits. Built from
# GitHub's public data (GithubProfileGateway::Profile), stored nowhere.
class Preview
  RANGE = "12m".freeze
  WEEKS = Progress::SummarizeService::WEEKS
  RECENT_GROUPS = Progress::GatherService::RECENT_GROUPS
  # Projects past the cards listed by name; GitHub lists the rest.
  LISTED = 20

  # A project's card, as the stage draws one from GitHub alone. weeks: its
  # commits per ISO week, oldest first, this week last.
  Card = Data.define(:project, :repo, :weeks, :last_commit) do
    delegate :name, :rank, to: :project
    delegate :description, :url, :homepage, to: :repo

    def commits
      weeks.sum
    end

    def archived?
      repo.archived
    end
  end

  # A row of Recent commits: one project's commits on one day, newest first.
  Group = Data.define(:project, :date, :commits)

  attr_reader :profile, :latest, :today

  delegate :login, :avatar_url, :bio, :website, to: :profile

  # The first day a preview reads: the 12-month chart's first or the cards'
  # first week, whichever is earlier.
  def self.first_day(today)
    [ Progress::Window.new(range: RANGE, today: today, first_activity: nil).first, first_week(today) ].min
  end

  # The Monday that starts the cards' 52 weeks.
  def self.first_week(today)
    today - (today.cwday - 1) - ((WEEKS - 1) * 7)
  end

  # latest: GithubProfileGateway::Commit, newest first.
  def initialize(profile:, latest:, today:)
    @profile = profile
    @latest = latest
    @today = today
  end

  def display_name
    profile.name || login
  end

  # The repos with commits in the window, busiest first. The rank gives a
  # project its colour, as on the stage.
  def projects
    @projects ||= begin
      counted = profile.repos.filter_map { |repo| [ repo, commits_in(repo, window.span) ] if commits_in(repo, window.span).positive? }
      counted.sort_by { |repo, count| [ -count, repo.full_name ] }.each_with_index.map do |(repo, count), rank|
        Progress::Projects::Project.new(repo: repo.full_name, name: repo.name, commits: count, rank: rank)
      end
    end
  end

  def commits
    projects.sum(&:commits)
  end

  def empty?
    projects.empty?
  end

  # A card per project with a colour; the rest are listed after them.
  def cards
    projects.select { |project| ProgressChart::Palette.colored?(project.rank) }.map { |project| card(project) }
  end

  def rest
    projects.reject { |project| ProgressChart::Palette.colored?(project.rank) }
  end

  def window
    @window ||= Progress::Window.new(range: RANGE, today: today, first_activity: first_activity)
  end

  def section
    @section ||= Section.new(self)
  end

  # Commits per project in each of the window's points, and over its span.
  def counts(days)
    projects.to_h { |project| [ project.repo, commits_in(repo(project.repo), days) ] }
  end

  # The latest commits by project and day, as many rows as the stage shows.
  def recent
    groups = latest.group_by { |commit| [ commit.repo, commit.authored_at.utc.to_date ] }
    groups.filter_map do |(full_name, date), commits|
      project = projects.find { |own| own.repo == full_name }
      Group.new(project: project, date: date, commits: commits) if project
    end.first(RECENT_GROUPS)
  end

  private

  def repo(full_name)
    profile.repos.find { |repo| repo.full_name == full_name }
  end

  def commits_in(repo, days)
    repo.days.sum { |day, count| days.cover?(day) ? count : 0 }
  end

  def first_activity
    profile.repos.flat_map { |repo| repo.days.keys }.min
  end

  def card(project)
    repo = repo(project.repo)
    first = self.class.first_week(today)
    weeks = Array.new(WEEKS, 0)
    repo.days.each do |day, count|
      week = (day - first).to_i / 7
      weeks[week] += count if day >= first && week < WEEKS
    end
    Card.new(project: project, repo: repo, weeks: weeks, last_commit: repo.days.keys.max)
  end
end
