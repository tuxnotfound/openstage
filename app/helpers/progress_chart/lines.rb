module ProgressChart
  # Each project's commits added up across the period: one line per project
  # through the centers of the buckets, on the bars' axis. The scale
  # fits the busiest project's total, so lines never stack.
  class Lines
    attr_reader :frame, :slot, :scale

    # repos: rank order, which draws the busiest project last, on top.
    def initialize(buckets, repos:, colors:, frame:)
      @frame = frame
      @repos = repos
      @colors = colors
      @slot = (frame.right - frame.left).to_f / buckets.size
      @buckets = buckets
      @sums = running_sums(buckets)
      @scale = Scale.new(@sums.values.map { |sums| sums.last.to_i }.max.to_i, top: frame.top, bottom: frame.bottom)
    end

    def center(index)
      frame.left + (slot * (index + 0.5))
    end

    # [path, stroke] per project with commits, the busiest last.
    def paths
      shown.reverse.map { |repo| [ path(repo), @colors[repo] ] }
    end

    # A small open dot where each line ends, today or at the period's end.
    def ends(radius = 2.6)
      return "" if @buckets.empty?

      x = center(@buckets.last.span.index)
      shown.map { |repo| dot(x, scale.y(@sums[repo].last), radius) }.join
    end

    # The area under one project's line, for its wash under a filter.
    def wash(repo)
      return "" unless @sums.key?(repo) && @buckets.any?

      "#{path(repo)}L#{num(center(@buckets.last.span.index))},#{frame.bottom}Z"
    end

    # The line's points: the baseline at the left edge, then each bucket so far.
    def points(repo)
      sums = @sums.fetch(repo) { Array.new(@buckets.size, 0) }
      [ [ frame.left, frame.bottom ] ] + @buckets.each_with_index.map { |bucket, i| [ center(bucket.span.index), scale.y(sums[i]) ] }
    end

    # Commits added up to the end of a bucket.
    def so_far(repo, index)
      at = @buckets.index { |bucket| bucket.span.index == index }
      at && @sums.key?(repo) ? @sums[repo][at] : 0
    end

    private

    def shown
      @repos.select { |repo| @sums.key?(repo) } + (@sums.keys - @repos)
    end

    def running_sums(buckets)
      repos = buckets.flat_map { |bucket| bucket.counts.select { |_repo, n| n.positive? }.keys }.uniq
      repos.index_with do |repo|
        total = 0
        buckets.map { |bucket| total += bucket.counts.fetch(repo, 0) }
      end
    end

    def path(repo)
      points(repo).each_with_index.map { |(x, y), i| "#{i.zero? ? 'M' : 'L'}#{num(x)},#{num(y)}" }.join
    end

    def dot(cx, cy, r)
      "M#{num(cx - r)},#{num(cy)}a#{r},#{r} 0 1,0 #{r * 2},0a#{r},#{r} 0 1,0 #{-r * 2},0Z"
    end

    def num(value)
      CardLayout::Shapes.num(value)
    end
  end
end
