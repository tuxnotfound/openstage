module Progress
  # Everything the progress section shows for one period: the counts
  # (TallyService) and the entries that get words (PickService).
  class ComposeService < ApplicationService
    # Entries with words on the page.
    PAGE_CAP = 6

    # order ranks every entry of the period the way the pick does, for a card
    # that decides by room which ones get words.
    Section = Data.define(:tally, :labels, :pick, :project, :order)

    attr_accessor :user, :range, :offset, :repo, :cap, :swapped_ids
    attr_reader :section

    validates :user, presence: true

    private

    def execute
      tally = TallyService.new(user: user, range: range, offset: offset, repo: repo)
      return unless run(tally)

      pick = pick_for(tally, cap || PAGE_CAP, swapped_ids)
      order = pick_for(tally, tally.items.size, [])
      return unless run(pick) && run(order)

      @section = Section.new(tally: tally, labels: PeriodLabels.new(tally.period), pick: pick, project: tally.projects.find(repo),
                             order: order.ranked)
    end

    def pick_for(tally, cap, swapped)
      PickService.new(items: tally.items, first_day: tally.first_active_day, last_day: tally.period.last_day, cap: cap,
                      swapped_ids: swapped)
    end

    def run(service)
      service.call
      absorb_errors(service)
    end
  end
end
