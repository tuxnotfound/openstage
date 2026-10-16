module Progress
  # Everything the progress section shows for one period: the counts
  # (TallyService) and the entries that get words (PickService).
  class ComposeService < ApplicationService
    # Entries with words on the page.
    PAGE_CAP = 6

    # selected: the projects in view, none for all. order ranks every entry of
    # the period the way the pick does, for a card that decides by room which
    # ones get words.
    Section = Data.define(:tally, :labels, :pick, :selected, :order) do
      # The one project in view; nil for all of them or several.
      def project
        selected.first if selected.one?
      end

      def filtered?
        selected.any?
      end

      # "openstage", "openstage + wheels-off", "3 projects"; or: "openstage or
      # wheels-off", "any of these 3 projects".
      def selection_name(alternatives: false)
        names = selected.map(&:name)
        return names.join(alternatives ? " or " : " + ") if names.size <= 2

        alternatives ? "any of these #{names.size} projects" : "#{names.size} projects"
      end
    end

    # repos: the projects in view; none for all of them.
    attr_accessor :user, :range, :offset, :repos, :cap, :swapped_ids
    attr_reader :section

    validates :user, presence: true

    private

    def execute
      tally = TallyService.new(user: user, range: range, offset: offset, repos: Array(repos))
      return unless run(tally)

      pick = pick_for(tally, cap || PAGE_CAP, swapped_ids)
      order = pick_for(tally, tally.items.size, [])
      return unless run(pick) && run(order)

      @section = Section.new(tally: tally, labels: PeriodLabels.new(tally.period), pick: pick, order: order.ranked,
                             selected: tally.projects.all.select { |project| Array(repos).include?(project.repo) })
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
