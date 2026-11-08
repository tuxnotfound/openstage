module Revenue
  # Some projects' MRR and paying subscriptions by day, in one currency: the one
  # most of their revenue is in on the latest day read, the rest converted at
  # each day's ECB rate (Rates). MRR comes in that currency's units. A currency
  # with no ECB rate cannot join another: it is left out and named (left_out),
  # unless it is the one most of it is in.
  class Levels
    Row = Data.define(:repo_id, :day, :currency, :mrr, :subscriptions)

    attr_reader :currency, :left_out

    def initialize(rows)
      @rates = rates_for(rows)
      @currency = most_in(rows)
      @left_out = []
      @mrr = {}
      @customers = {}
      rows.each { |row| count(row) }
      @left_out.uniq!
    end

    # { date => units } for a project.
    def mrr(repo_id)
      @mrr.fetch(repo_id, {})
    end

    # { date => paying subscriptions } for a project.
    def customers(repo_id)
      @customers.fetch(repo_id, {})
    end

    private

    # One currency converts nothing, so it reads no rates.
    def rates_for(rows)
      currencies = rows.map(&:currency).uniq
      return Rates.new({}) if currencies.size < 2

      Rates.for(currencies, from: rows.map(&:day).min)
    end

    # By what the latest day's amounts are worth in euros, where the ECB can
    # say, and by their size where it cannot.
    def most_in(rows)
      latest = rows.map(&:day).max
      amounts = rows.select { |row| row.day == latest }.group_by(&:currency).transform_values { |some| Money.units(some.sum(&:mrr), some.first.currency) }
      amounts.max_by { |currency, amount| [ @rates.convert(amount, currency, Rates::EURO, latest) || 0, amount ] }&.first
    end

    def count(row)
      add(@customers, row, row.subscriptions)
      amount = @rates.convert(Money.units(row.mrr, row.currency), row.currency, currency, row.day)
      amount ? add(@mrr, row, amount) : @left_out << row.currency
    end

    def add(totals, row, value)
      days = totals[row.repo_id] ||= {}
      days[row.day] = days.fetch(row.day, 0) + value
    end
  end
end
