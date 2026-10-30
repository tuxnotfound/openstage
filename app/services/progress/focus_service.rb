module Progress
  # Everything one project's page shows: the builder's page for that project
  # alone (GatherService), its card, the other projects' cards, and the latest
  # it shipped or published, in the builder's words, whenever that was. The
  # project is named as in its URL, by the repo's own name, matched without
  # regard to case, as GitHub matches it.
  class FocusService < ApplicationService
    # Another builder with public commits on the same repo, and how many;
    # nil while they hide its commits on their own page for it.
    CoBuilder = Data.define(:user, :commits)
    # A line of its Details: what it is, and its value as the page writes it.
    Fact = Data.define(:label, :value)

    # slug: the repo's name without its owner; range: a Window range; show:
    # the numbers its chart draws, by key in line order, none for the
    # default. reveal: a repo the builder hid, shown anyway (Entry.counted_on_page).
    attr_accessor :user, :slug, :range, :show, :reveal
    # page: the GatherService run for this project; others: the rest of the
    # builder's cards; news: the latest highlight; highlights: how many there
    # are, ever; first_commit: a time, which its share card reads; facts: its
    # Details as visitors see them, Facts; last_commit: the day of its latest
    # commit, nil while its builder hides its commits; co_builders:
    # CoBuilders, busiest first, the ones with no count shown last.
    attr_reader :project, :page, :card, :others, :news, :highlights, :first_commit, :facts, :last_commit, :co_builders

    validates :user, :slug, presence: true

    private

    def execute
      @project = find_project
      unless project
        errors.add(:slug, "names no project on this page")
        return
      end

      gather = GatherService.new(user: user, range: range, repos: [ project.repo ], show: show, reveal: reveal, lone: true)
      gather.call
      return unless absorb_errors(gather)

      @page = gather
      @card, @others = split_cards(gather.cards)
      @news = user.entries.listed_on_page(reveal: reveal).highlights.where(repo_name: project.repo).chronological.first
      @highlights = counted.highlights.where(repo_name: project.repo).count
      @first_commit = counted.commits.where(repo_name: project.repo).minimum(:occurred_at)
      @facts = details
      @last_commit = card&.last_commit if commits_shown?
      @co_builders = co_builders_on(project.repo)
    end

    # Two repos may share a name under different owners; the busier one wins.
    def find_project
      Projects.new(counted).all.find { |project| project.repo.split("/").last.casecmp?(slug) }
    end

    # What its numbers count; news, the one entry it lists, reads the listed ones.
    def counted
      user.entries.counted_on_page(reveal: reveal)
    end

    # Its count of commits and its first one while visitors see its commits,
    # then what it shipped and published, its stars and its website, each
    # where it has any.
    def details
      repo = card&.github_repo
      [ *(commit_facts if commits_shown?),
        (Fact.new(label: "Shipped and published", value: highlights) if highlights.positive?),
        (Fact.new(label: "Stars on GitHub", value: repo.stars_count) if repo&.stars_count.to_i.positive?),
        (Fact.new(label: "Website", value: repo.site_host) if repo&.site_host) ].compact
    end

    # Whether visitors see its commits (SummarizeService::Card): while its
    # builder hides them, its page shows no count of them and no time taken
    # from them.
    def commits_shown?
      card.nil? || card.commits_shown?
    end

    def commit_facts
      [ Fact.new(label: "Commits, all time", value: project.commits),
        (Fact.new(label: "First commit", value: first_commit.to_date.strftime("%b %-d, %Y")) if first_commit) ]
    end

    # Teammates who show the same repo on their own pages: only what their
    # pages already make public, so no count from one who hides its commits
    # there, and those come after the ones who show theirs.
    def co_builders_on(repo)
      counts = Entry.publicly_counted.without_tooling_noise.commits.where(repo_name: repo).where.not(user_id: user.id)
                    .joins(:user).merge(User.active).group(:user_id).count
      hiding = GithubRepo.where(user_id: counts.keys, full_name: repo).reject { |copy| copy.public_number?("commits") }.map(&:user_id)
      User.where(id: counts.keys).map { |builder| CoBuilder.new(user: builder, commits: (counts[builder.id] unless hiding.include?(builder.id))) }
          .sort_by { |co| [ co.commits ? 0 : 1, -co.commits.to_i, co.user.username ] }
    end

    def split_cards(cards)
      mine, rest = cards.partition { |card| card.repo == project.repo }
      [ mine.first, rest ]
    end
  end
end
