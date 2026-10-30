module Progress
  # Everything the progress section shows for one period: the counts
  # (TallyService) and the entries that get words (PickService).
  class ComposeService < ApplicationService
    # Entries with words on the page.
    PAGE_CAP = 6

    # selected: the projects in view, none for all.
    Section = Data.define(:tally, :labels, :pick, :selected) do
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

    # repos: the projects in view; none for all of them. rolling: a Window
    # that ends today, as the public page shows; else a calendar Period.
    # reveal: a repo the builder hid, shown anyway (Entry.counted_on_page).
    # counting: what the page's chart also counts (TallyService::Counting).
    # shown_only: only the commits visitors see count (TallyService).
    attr_accessor :user, :range, :offset, :repos, :cap, :swapped_ids, :rolling, :reveal, :counting, :shown_only
    attr_reader :section

    validates :user, presence: true

    private

    # The section ranks the projects, so the tally takes where the work began
    # from the reads that rank them.
    def execute
      tally = TallyService.new(user: user, range: range, offset: offset, repos: Array(repos), rolling: rolling, reveal: reveal,
                               counting: counting, ranked: true, shown_only: shown_only)
      return unless run(tally)

      pick = PickService.new(items: tally.items, first_day: tally.first_active_day, last_day: tally.period.last_day,
                             cap: cap || PAGE_CAP, swapped_ids: swapped_ids)
      return unless run(pick)

      @section = Section.new(tally: tally, labels: tally.period.labels, pick: pick,
                             selected: tally.projects.all.select { |project| Array(repos).include?(project.repo) })
    end

    def run(service)
      service.call
      absorb_errors(service)
    end
  end
end
