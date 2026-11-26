module Feed
  # A few of the latest feed entries for the home page, newest first, at most
  # PER_BUILDER from any one builder and one from any project of theirs, read
  # from the feed's first cards, so neither one busy builder nor one busy
  # project fills them all.
  class LatelyService < ApplicationService
    COUNT = 12
    PER_BUILDER = 3

    attr_reader :entries

    private

    def execute
      list = ListService.new(scope: Entry.on_feed, per_page: COUNT)
      list.call
      return unless absorb_errors(list)

      @entries = list.cards.group_by { |card| card.user.id }.values
                     .flat_map { |cards| cards.flat_map(&:entries).uniq(&:repo_name).first(PER_BUILDER) }
                     .sort_by(&:occurred_at).reverse.first(COUNT)
    end
  end
end
