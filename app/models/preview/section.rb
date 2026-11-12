class Preview
  # A preview's 12 months, in the shape ProgressChart::Trend reads a stage's
  # section (Progress::ComposeService): its tally's window, totals, projects
  # and points, and the window's words. So the preview's chart is drawn by
  # the code that draws the landing's sample stage.
  class Section
    Totals = Data.define(:counts)
    Bucket = Data.define(:counts)
    # day_counts: read by a chart drawn by day; 12 months never are.
    Tally = Data.define(:period, :totals, :projects, :buckets, :day_counts)
    Projects = Data.define(:all) do
      def find(repo)
        all.find { |project| project.repo == repo }
      end
    end

    def initialize(preview)
      @preview = preview
    end

    def tally
      @tally ||= Tally.new(period: window, totals: Totals.new(counts: @preview.counts(window.span)),
                           projects: Projects.new(all: @preview.projects), day_counts: {},
                           buckets: window.buckets.map { |bucket| Bucket.new(counts: @preview.counts(bucket.first..bucket.last)) })
    end

    def labels
      window.labels
    end

    # The project a page shows alone; a preview shows them all.
    def project
      nil
    end

    def filtered?
      false
    end

    private

    def window
      @preview.window
    end
  end
end
