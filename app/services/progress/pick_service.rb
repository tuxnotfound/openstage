module Progress
  # Who gets words on the progress section and its cards. It never reads the
  # text. Pins come first and always stay. Then shipped entries, then
  # published ones, in rounds over six equal day spans of the period, one per
  # span per round and newer first, so the words spread across the period
  # instead of crowding its busiest week.
  class PickService < ApplicationService
    SPANS = 6

    # items: the period's Progress::TallyService::Items. first_day starts the
    # domain: the first day with a commit or an entry. swapped_ids: entries
    # the builder swapped in on a card, in the order they were.
    attr_accessor :items, :first_day, :last_day, :cap, :swapped_ids
    # kept and left are in date order; ranked is kept in rank order, so a
    # card that runs out of room drops from its end.
    attr_reader :kept, :left, :ranked

    validates :last_day, presence: true
    validates :cap, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    private

    def execute
      @ranked = items.select(&:pinned?).sort_by { |item| newest(item) }.first(cap)
      @held = ranked.map { |item| span_of(item) }.to_set
      fill(:shipped)
      fill(:published)
      swap_in
      ids = ranked.map(&:id)
      @kept = ranked.sort_by { |item| [ item.date, item.id ] }
      @left = items.reject { |item| ids.include?(item.id) }.sort_by { |item| [ item.date, item.id ] }
    end

    def fill(kind)
      lanes = lanes_for(kind)
      round = 0
      while ranked.size < cap && lanes.any?(&:any?)
        round_of(lanes, round).sort_by { |item| newest(item) }.each { |item| take(item) }
        round += 1
      end
    end

    # One lane per span, newest first.
    def lanes_for(kind)
      candidates = items.select { |item| !item.pinned? && item.kind == kind }.sort_by { |item| newest(item) }
      Array.new(SPANS) { |span| candidates.select { |item| span_of(item) == span } }
    end

    # The next entry from each lane. A span that already holds one skips round one.
    def round_of(lanes, round)
      lanes.each_with_index.filter_map { |lane, span| lane.shift unless round.zero? && @held.include?(span) }
    end

    def take(item)
      return if ranked.size >= cap

      ranked << item
      @held << span_of(item)
    end

    # Each swap pushes out the lowest-ranked entry that is neither a pin nor
    # an earlier swap.
    def swap_in
      swapped = []
      Array(swapped_ids).map(&:to_i).each do |id|
        item = items.find { |candidate| candidate.id == id }
        next if item.nil? || ranked.include?(item)

        out = ranked.rindex { |kept| !kept.pinned? && !swapped.include?(kept) }
        ranked.delete_at(out) if out
        next if ranked.size >= cap

        ranked << item
        swapped << item
      end
    end

    def span_of(item)
      [ SPANS - 1, SPANS * (item.date - domain_start).to_i / domain_days ].min
    end

    def domain_start
      @domain_start ||= ([ first_day ].compact + items.map(&:date)).min
    end

    def domain_days
      @domain_days ||= (last_day - domain_start).to_i + 1
    end

    def newest(item)
      [ -item.date.jd, -item.id ]
    end
  end
end
