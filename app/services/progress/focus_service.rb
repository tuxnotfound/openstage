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

    # slug: the repo's name without its owner; range: a Window range; show:
    # the numbers its chart draws, by key in line order, none for the
    # default. reveal: a repo the builder hid, shown anyway (Entry.on_page).
    attr_accessor :user, :slug, :range, :show, :reveal
    # page: the GatherService run for this project; others: the rest of the
    # builder's cards; news: the latest highlight; highlights: how many there
    # are, ever; first_commit: a time; co_builders: CoBuilders, busiest first,
    # the ones with no count shown last.
    attr_reader :project, :page, :card, :others, :news, :highlights, :first_commit, :co_builders

    validates :user, :slug, presence: true

    # Whether visitors see its commits (SummarizeService::Card): while its
    # builder hides them, its page shows no count of them and no time taken
    # from them.
    def commits_shown?
      card.nil? || card.commits_shown?
    end

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
      @news = entries.highlights.where(repo_name: project.repo).chronological.first
      @highlights = entries.highlights.where(repo_name: project.repo).count
      @first_commit = entries.commits.where(repo_name: project.repo).minimum(:occurred_at)
      @co_builders = co_builders_on(project.repo)
    end

    # Two repos may share a name under different owners; the busier one wins.
    def find_project
      Projects.new(entries).all.find { |project| project.repo.split("/").last.casecmp?(slug) }
    end

    def entries
      user.entries.on_page(reveal: reveal)
    end

    # Teammates who show the same repo on their own pages: only what their
    # pages already make public, so no count from one who hides its commits
    # there, and those come after the ones who show theirs.
    def co_builders_on(repo)
      counts = Entry.publicly_visible.without_tooling_noise.commits.where(repo_name: repo).where.not(user_id: user.id)
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
