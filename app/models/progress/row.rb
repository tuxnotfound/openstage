module Progress
  # A row of a chart filter's table, which is the chart's key: one of the
  # builder's projects or, on analytics, a page (their own, or a project's).
  # key: a repo's full name, or Analytics::CountService::PAGE for their own
  # page; rank: its colour, nil for ink; repo: its synced GithubRepo, nil
  # with none; on: in view on the chart; counted and shown: the numbers it
  # counts and the ones it shows, by key; site: where its site visits stand
  # (SiteVisits::Slot#state), nil without a synced repo and on analytics,
  # which only reads its cells.
  Row = Data.define(:key, :name, :rank, :repo, :on, :counted, :shown, :site) do
    def initialize(site: nil, **fields)
      super
    end

    def counts?(number)
      counted.include?(number)
    end

    def shows?(number)
      shown.include?(number)
    end

    # Whether the table lists its value of a number: visitors see the ones
    # it shows, and its builder, managing what they see, also the ones it
    # counts and hides from them.
    def lists?(number, manage)
      shows?(number) || (manage && counts?(number))
    end

    # Its builder's switch for a number it counts: on while they pick it for
    # visitors; nil without a synced repo or a count, and for site visits
    # that do not count now, where flipping it would change nothing visitors
    # see.
    def pick(number)
      repo.picks?(number) if repo && counts?(number) && (number != "visits" || site == :counting)
    end

    # What stands in the switch's place for site visits, on a synced repo:
    # :paused while Free counts another project, :set_up while none count
    # (the script off, or on and waiting for its first visit); nil where a
    # switch stands.
    def link(number)
      return unless repo && number == "visits"

      if site == :paused then :paused
      elsif pick(number).nil? then :set_up
      end
    end
  end
end
