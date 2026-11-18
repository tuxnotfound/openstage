module Analytics
  # The MRR tab's own parts, for a window and the projects in view, in the
  # currency the chart is in: each Stripe product counted for one of them,
  # with its MRR and subscriptions on the last day read, converted at that
  # day's rate as Revenue::Levels converts, largest first (products); and
  # where MRR stood at the end of each week of the window, or each month
  # past 90 days and of days picked by their length, cut at the window's
  # days, newest first, with what the week or month added or took (steps).
  # Never a sum of days: MRR is a level.
  class RevenueParts
    # mrr: in the currency's units; row: its project's Progress::Row.
    Product = Data.define(:name, :row, :mrr, :subscriptions)
    # days: the week's or month's, cut at the window's; change: what it
    # added, below zero for what it took; mrr: where it stood at its end.
    Step = Data.define(:days, :change, :mrr)

    # book: the builder's Revenue::Book; window: the Progress::Window the
    # totals cover; counts: the tab's Progress::Counts; rows: the tab's
    # Progress::Rows.
    def initialize(book:, window:, counts:, rows:)
      @book = book
      @window = window
      @counts = counts
      @rows = rows
      @in_view = rows.select(&:on)
    end

    # Whether no product counts for any project: nothing to list.
    def none?
      @rows.empty?
    end

    def currency
      @counts.currency
    end

    def unit
      @window.unit == :month ? :month : :week
    end

    def products
      @products ||= begin
        by_repo = @in_view.select(&:repo).index_by { |row| row.repo.id }
        days = @book.last_day(by_repo.values.map(&:repo))
        rates = Revenue::Rates.for(days.map { |each| each[3] } | [ currency ], from: @book.read_day)
        days.group_by(&:first).filter_map { |_, some| product(some, by_repo, rates) }.reject { |each| each.mrr.zero? && each.subscriptions.zero? }
            .sort_by { |each| [ -each.mrr, each.name ] }
      end
    end

    def steps
      keys = @in_view.map(&:key)
      began = @counts.first_day("mrr", keys)
      first = [ @window.span&.first, began ].compact.max if began
      return [] unless first && first <= @window.last

      spans(first).map { |days| Step.new(days: days, change: level(keys, days.last) - level(keys, days.first - 1), mrr: level(keys, days.last)) }.reverse
    end

    private

    # Its rows, one per currency, as [id, name, repo id, currency, mrr,
    # subscriptions]; nil when a currency has no rate to convert by.
    def product(some, by_repo, rates)
      amounts = some.map { |_, _, _, from, mrr| rates.convert(Revenue::Money.units(mrr, from), from, currency, @book.read_day) }
      return if amounts.include?(nil)

      _, name, repo_id = some.first
      Product.new(name: name, row: by_repo.fetch(repo_id), mrr: amounts.sum, subscriptions: some.sum(&:last))
    end

    def level(keys, day)
      keys.sum { |key| @counts.sum("mrr", key, day..day) }
    end

    # Each week from its Monday, or each month from its first, cut at first
    # and at the window's last day.
    def spans(first)
      last = @window.last
      starts = unit == :week ? (first - (first.cwday - 1)).step(last, 7).to_a : month_starts(first, last)
      starts.map { |start| [ start, first ].max..[ unit == :week ? start + 6 : start.end_of_month, last ].min }
    end

    def month_starts(first, last)
      Enumerator.produce(first.beginning_of_month) { |month| month >> 1 }.take_while { |month| month <= last }
    end
  end
end
