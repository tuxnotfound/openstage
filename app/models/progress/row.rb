module Progress
  # A row of a chart filter's table, which is the chart's key: one of the
  # builder's projects or, on analytics, a page (their own, or a project's).
  # key: a repo's full name, or Analytics::CountService::PAGE for their own
  # page; rank: its colour, nil for ink; repo: its synced GithubRepo, nil
  # with none; on: in view on the chart; counted and shown: the numbers it
  # counts and the ones it shows, by key.
  Row = Data.define(:key, :name, :rank, :repo, :on, :counted, :shown) do
    def counts?(number)
      counted.include?(number)
    end

    def shows?(number)
      shown.include?(number)
    end
  end
end
