module ProgressChart
  # One hover column per bucket and what its tooltip says: the bucket, its
  # commits by project (added up so far on the Lines chart), and its entries
  # led by their disc number, or a dot for those without words.
  class Tooltips
    Column = Data.define(:left, :width, :title, :total, :rows, :notes)
    Row = Data.define(:name, :n, :so_far, :color, :repo)
    Note = Data.define(:mark, :title, :shipped)

    def initialize(page)
      @page = page
      @section = page.section
    end

    def columns
      series = @page.series
      tally.buckets.map do |bucket|
        span = bucket.span
        Column.new(left: @page.left(series.frame.left + (series.slot * span.index)),
                   width: @page.left(series.frame.left + series.slot) - @page.left(series.frame.left),
                   title: @section.labels.bucket_title(span),
                   total: span.future ? "Still ahead" : "#{bucket.total} #{'commit'.pluralize(bucket.total)}",
                   rows: rows(bucket.counts, span.index), notes: bucket.items.map { |item| note(item) })
      end
    end

    # The period's projects, busiest first, with their colors and counts.
    def rows(counts, index = nil)
      counts.select { |_repo, n| n.positive? }.sort_by { |repo, n| [ -n, repo.to_s ] }.map do |repo, n|
        project = repo && tally.projects.find(repo)
        Row.new(name: project&.name || "No repo", n: n, so_far: index && @page.lines? ? @page.series.so_far(repo, index) : nil,
                color: Palette.project_color(project&.rank), repo: repo)
      end
    end

    private

    def tally
      @section.tally
    end

    def note(item)
      number = @section.pick.kept.index(item)
      Note.new(mark: number ? (number + 1).to_s : "·", title: item.title, shipped: item.shipped?)
    end
  end
end
