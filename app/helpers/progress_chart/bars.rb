module ProgressChart
  # Commits per bucket as bars stacked by project, the busiest project of all
  # time at the bottom. A 2px gap is carved off the top of every segment under
  # another, and the last one gets a rounded top.
  class Bars
    # x is the bar's left edge; top is where its stack ends.
    Column = Data.define(:cx, :x, :top)
    # The plot, in the drawing's units.
    Frame = Data.define(:left, :right, :top, :bottom)

    attr_reader :frame, :slot, :width, :scale, :columns, :paths

    # repos: the stacking order. colors: repo to fill.
    def initialize(buckets, repos:, colors:, frame:)
      @frame = frame
      @colors = colors
      @slot = (frame.right - frame.left).to_f / buckets.size
      @width = (slot * 0.62).clamp(3, 24)
      @scale = Scale.new(buckets.map(&:total).max.to_i, top: frame.top, bottom: frame.bottom)
      @paths = Hash.new { |hash, repo| hash[repo] = +"" }
      @columns = buckets.each_with_index.map { |bucket, i| stack(bucket, i, repos) }
    end

    # [path, fill] per project, bottom first.
    def fills
      paths.map { |repo, path| [ path, @colors[repo] ] }
    end

    def center(index)
      frame.left + (slot * (index + 0.5))
    end

    private

    def stack(bucket, index, repos)
      cx = center(index)
      x = cx - (width / 2)
      segments = bucket.counts.select { |_repo, n| n.positive? }.sort_by { |repo, _n| repos.index(repo) || repos.size }
      below = 0
      segments.each_with_index do |(repo, n), k|
        draw(repo, x, scale.y(below), scale.y(below + n), last: k == segments.size - 1)
        below += n
      end
      Column.new(cx: cx, x: x, top: scale.y(bucket.total))
    end

    def draw(repo, x, bottom, top, last:)
      return paths[repo] << round_top(x, top, width, bottom - top, 4) if last

      top = [ top + 2, bottom - 1 ].min
      paths[repo] << "M#{num(x)},#{num(top)}h#{num(width)}v#{num(bottom - top)}h#{num(-width)}Z"
    end

    def round_top(x, y, w, h, radius)
      r = radius.clamp(0, [ h, w / 2 ].min)
      "M#{num(x)},#{num(y + h)}V#{num(y + r)}Q#{num(x)},#{num(y)} #{num(x + r)},#{num(y)}" \
        "H#{num(x + w - r)}Q#{num(x + w)},#{num(y)} #{num(x + w)},#{num(y + r)}V#{num(y + h)}Z"
    end

    def num(value)
      CardLayout::Shapes.num(value)
    end
  end
end
