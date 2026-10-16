module CardLayout
  class StarChart
    # The bottom of the left column: next week's goal, then the series mark
    # and the builder's link, which is never cut: it is the growth loop.
    class Foot
      GOAL_LH = 20

      # Where the arrow before the goal goes, or nil without a goal.
      attr_reader :arrow

      def initialize(chart)
        @chart = chart
        @canvas = chart.canvas
        @palette = chart.palette
      end

      # Draws the goal and the footer, and says where the goal starts.
      def draw
        lines = goal_lines
        top = FOOT_TOP - 14 - (lines.size * GOAL_LH)
        goal(lines, top) if lines.any?
        footer
        top
      end

      private

      def goal_lines
        goal = CardText.clean(@chart.card.week_card.next_goal)
        return [] unless @chart.shows?("goal") && goal.present?

        Lines.new(goal, :dm_sans_semibold, 0, rule: :phrases).balance(16, HEAD_W, 2) ||
          StarChart.hard_wrap(goal, HEAD_W) { |text| CardText.width(text, size: 16, face: :dm_sans_semibold) }
      end

      # The lines set the shared baseline; NEXT and the arrow hang from it.
      def goal(lines, top)
        baseline = top + StarChart.base_in(GOAL_LH, 16)
        @canvas.put("NEXT", :dm_mono_regular, 11.5, LEFT, baseline, @palette[:gold], spacing: 0.1)
        @arrow = { x: LEFT + GUTTER, y: top + 4 }
        lines.each_with_index do |line, k|
          @canvas.put(line, :dm_sans_semibold, 16, LEFT + HEAD_X, baseline + (k * GOAL_LH), @palette[:title])
        end
      end

      def footer
        @canvas.draw(:rules, Shapes.rule(LEFT, LEFT + WIDTH, FOOT_TOP))
        mark, size = fit_footer
        height = 1.3 * size
        top = FOOT_TOP + 1 + 10
        @canvas.put(mark, :dm_mono_regular, 11, LEFT, top + ((height - 14.3) / 2) + (0.99 * 11), @palette[:muted], spacing: 0.1)
        @canvas.put_end(link, :dm_sans_bold, size, LEFT + WIDTH, top + (0.99 * size), @palette[:title])
      end

      # The link steps down, the mark shortens, then the link steps down again.
      def fit_footer
        [ [ "STAR CHART BY OPENSTAGE", 16 ], [ "STAR CHART BY OPENSTAGE", 14 ], [ "OPENSTAGE", 14 ] ].find do |mark, size|
          CardText.width(mark, size: 11, face: :dm_mono_regular, spacing: 1.1) + 20 + CardText.width(link, size: size, face: :dm_sans_bold) <= WIDTH
        end || [ "OPENSTAGE", 13 ]
      end

      def link
        "openstage.dev/#{@chart.card.user.username}"
      end
    end
  end
end
