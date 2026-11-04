module Analytics
  # Some days in a builder's zone, read in two parts: the days the rollup
  # closed, from their totals (PageDay, PageCount, EntryClickDay), and what
  # came since User#rolled_up_to, from the raw rows. first and last may be
  # nil, for every day.
  class Split
    def initialize(user, first: nil, last: nil)
      @user = user
      @first = first
      @last = last
    end

    def totals(scope)
      scope.where(day: @first..@last)
    end

    # at: the rows' time column.
    def raw(scope, at)
      scope.where(at => start..finish)
    end

    private

    def start
      [ @user.rolled_up_to, @first&.in_time_zone(@user.zone) ].compact.max
    end

    def finish
      @last&.in_time_zone(@user.zone)&.end_of_day
    end
  end
end
