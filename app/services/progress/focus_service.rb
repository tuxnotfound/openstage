module Progress
  # Everything one project's page shows: the builder's page for that project
  # alone (GatherService), its card, the other projects' cards, and the latest
  # it shipped or published, in the builder's words, whenever that was. The
  # project is named as in its URL, by the repo's own name, matched without
  # regard to case, as GitHub matches it.
  class FocusService < ApplicationService
    # slug: the repo's name without its owner; range: a Window range.
    attr_accessor :user, :slug, :range
    # page: the GatherService run for this project; others: the rest of the
    # builder's cards; news: the latest highlight; highlights: how many there
    # are, ever; first_commit: a time.
    attr_reader :project, :page, :card, :others, :news, :highlights, :first_commit

    validates :user, :slug, presence: true

    private

    def execute
      @project = find_project
      unless project
        errors.add(:slug, "names no project on this page")
        return
      end

      gather = GatherService.new(user: user, range: range, repos: [ project.repo ])
      gather.call
      return unless absorb_errors(gather)

      @page = gather
      @card, @others = split_cards(gather.cards)
      @news = entries.highlights.where(repo_name: project.repo).chronological.first
      @highlights = entries.highlights.where(repo_name: project.repo).count
      @first_commit = entries.commits.where(repo_name: project.repo).minimum(:occurred_at)
    end

    # Two repos may share a name under different owners; the busier one wins.
    def find_project
      Projects.new(entries).all.find { |project| project.repo.split("/").last.casecmp?(slug) }
    end

    def entries
      user.entries.publicly_visible.without_tooling_noise
    end

    def split_cards(cards)
      mine, rest = cards.partition { |card| card.repo == project.repo }
      [ mine.first, rest ]
    end
  end
end
