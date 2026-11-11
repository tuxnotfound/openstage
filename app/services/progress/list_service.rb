module Progress
  # The stage's list of a builder's projects past the ones with a card, the
  # ones with a colour (ProgressChart::Palette), so a builder with hundreds of
  # repos keeps a page a visitor can read: found by name, the live ones alone
  # when asked, sorted by latest commit, by commits over the cards' 52 weeks
  # or by name, a page at a time, each project on the page with its card
  # (SummarizeService) for its counts and its weekly line. A project whose
  # builder hides its commits shows none here either, and sorts as if it had
  # none, so its place gives nothing away.
  class ListService < ApplicationService
    PER_PAGE = 25

    # listing: a Listing. projects: the builder's ranked projects
    # (Projects#all) when the caller has read them already; read here otherwise.
    attr_accessor :user, :listing, :projects
    # cards: the page's SummarizeService::Cards, in the list's order; count:
    # the projects past the cards; live_count: how many of those are live;
    # found: how many the search and the filter keep; page: the page shown,
    # never past the last; pages: at least one.
    attr_reader :cards, :count, :live_count, :found, :page, :pages

    validates :user, :listing, presence: true

    private

    def execute
      @count = rest.size
      @live_count = rest.count { |project| live?(project) }
      matches = sorted(rest.select { |project| match?(project) })
      @found = matches.size
      @pages = [ found.fdiv(PER_PAGE).ceil, 1 ].max
      @page = [ listing.page, pages ].min
      summarize(matches.slice((page - 1) * PER_PAGE, PER_PAGE))
    end

    def rest
      @rest ||= (projects || Projects.new(user.entries.counted_on_page).all).reject { |project| ProgressChart::Palette.colored?(project.rank) }
    end

    def live?(project)
      repos[project.repo]&.live? || false
    end

    def repos
      @repos ||= user.github_repos.by_full_name(rest.map(&:repo))
    end

    def match?(project)
      return false if listing.live && !live?(project)

      listing.query.empty? || project.name.downcase.include?(listing.query.downcase)
    end

    # Ties go by name, so a page never shuffles between two reads.
    def sorted(list)
      case listing.sort
      when "commits" then list.sort_by { |project| [ -year_count(project), *latest(project), project.name.downcase ] }
      when "name" then list.sort_by { |project| [ project.name.downcase, project.repo ] }
      else list.sort_by { |project| [ *latest(project), project.name.downcase ] }
      end
    end

    # The newest first, then the ones with no commit visitors see.
    def latest(project)
      last = (last_commits[project.repo] if shown?(project))
      [ last ? 0 : 1, -last.to_i ]
    end

    def year_count(project)
      shown?(project) ? year_counts.fetch(project.repo, 0) : 0
    end

    # As SummarizeService::Card#commits_shown? reads it.
    def shown?(project)
      repo = repos[project.repo]
      repo.nil? || repo.public_number?("commits")
    end

    def last_commits
      @last_commits ||= commits.group(:repo_name).maximum(:occurred_at)
    end

    def year_counts
      @year_counts ||= commits.where(occurred_at: SummarizeService.first_week(user.zone).in_time_zone(user.zone)..).group(:repo_name).count
    end

    def commits
      user.entries.counted_on_page.commits.where(repo_name: rest.map(&:repo))
    end

    def summarize(page_projects)
      service = SummarizeService.new(user: user, projects: page_projects, zone: user.zone)
      service.call
      @cards = service.cards if absorb_errors(service)
    end
  end
end
