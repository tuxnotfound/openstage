module Analytics
  # One of analytics' lists: its rows, the busiest first, at most
  # ReportService::TOP of them, each [label, count] and, for a page of a
  # website, the project it is on; and what the list leaves out (other), 0
  # with nothing, so its rows and Other add up to its total.
  Ranked = Data.define(:rows, :other) do
    def any?
      rows.any? || other.positive?
    end
  end
end
