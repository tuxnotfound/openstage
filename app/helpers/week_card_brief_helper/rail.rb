module WeekCardBriefHelper
  # The Brief's rail and footer. The rail holds the week's four numbers, each
  # set as a phrase ("74 commits" reads at feed size where a label over the
  # number would not) and held against last week, in four equal bands. The
  # footer carries next week's goal and the builder's page.
  module Rail
    BAND = (FOOTER_RULE - FLY) / 4.0
    # A band hangs its figure this far below its rule.
    HANG = 16
    FIGURE_SIZE = 46
    CHANGE_SIZE = 12.5
    # The Openstage mark: the app icon's three rising bars on a rounded tile.
    MARK_TILE = "M112 0H400A112 112 0 0 1 512 112V400A112 112 0 0 1 400 512H112A112 112 0 0 1 0 400V112A112 112 0 0 1 112 0Z".freeze
    MARK_BARS = "M144 288H176A16 16 0 0 1 192 304V368A16 16 0 0 1 176 384H144A16 16 0 0 1 128 368V304A16 16 0 0 1 144 288Z" \
                "M240 224H272A16 16 0 0 1 288 240V368A16 16 0 0 1 272 384H240A16 16 0 0 1 224 368V240A16 16 0 0 1 240 224Z" \
                "M336 144H368A16 16 0 0 1 384 160V368A16 16 0 0 1 368 384H336A16 16 0 0 1 320 368V160A16 16 0 0 1 336 144Z".freeze

    def brief_rail(out, brief)
      out[:paths][:hair] << "M#{RAIL_RULE + 0.5} #{MASTHEAD_RULE + 22}V#{FOOTER_RULE - 22}"
      brief_text(out, "THE WEEK IN NUMBERS", :inter_bold, 10.5, RAIL_LEFT, FLY, brief[:t][:muted], spacing: 0.14)
      brief_figures(brief).each_with_index do |figure, k|
        top = FLY + (k * BAND)
        brief_hline(out, RAIL_LEFT, RIGHT, top) if k.positive?
        brief_figure(out, brief, figure, top + HANG + brief_cap(:newsreader_figures, FIGURE_SIZE))
      end
    end

    # [now, the phrase for one, for many, last week's], last week's only when
    # the card compares.
    def brief_figures(brief)
      now = brief[:card].totals
      before = brief[:wc].shows?("compare") ? brief[:card].previous&.totals : nil
      [ [ now.commits, "commit", "commits", before&.commits ],
        [ now.active_days, "of 7 days active", "of 7 days active", before&.active_days ],
        [ now.shipped, "shipped", "shipped", before&.shipped ],
        [ now.published, "published", "published", before&.published ] ]
    end

    # A zero recedes to the muted ink.
    def brief_figure(out, brief, figure, baseline)
      value, one, many, before = figure
      t = brief[:t]
      brief_text(out, value.to_s, :newsreader_figures, FIGURE_SIZE, RAIL_LEFT - 1, baseline, value.zero? ? t[:muted] : t[:ink])
      label_x = RAIL_LEFT + card_text_width(value.to_s, :newsreader_figures, FIGURE_SIZE) + 7
      brief_text(out, value == 1 ? one : many, :newsreader_text_regular, 19, label_x, baseline, value.zero? ? t[:muted] : t[:ink2])
      brief_change(out, brief, value, before, baseline + 23) unless before.nil?
    end

    # Down to zero, the change is the whole of last week: "31 last week" says
    # it without "▼ 31 from 31".
    def brief_change(out, brief, now, before, baseline)
      muted = brief[:t][:muted]
      if now == before
        brief_text(out, "Same as last week", :inter_medium, CHANGE_SIZE, RAIL_LEFT, baseline, muted)
      elsif now.zero?
        brief_text(out, before.to_s, :inter_figures, CHANGE_SIZE, RAIL_LEFT, baseline, muted)
        brief_text(out, "last week", :inter_medium, CHANGE_SIZE, RAIL_LEFT + card_text_width(before.to_s, :inter_figures, CHANGE_SIZE) + 4, baseline, muted)
      else
        brief_move(out, brief, now - before, before, baseline)
      end
    end

    def brief_move(out, brief, change, before, baseline)
      middle = baseline - (brief_cap(:inter_medium, CHANGE_SIZE) / 2)
      tip, foot = change.positive? ? [ middle - 3.5, middle + 3.5 ] : [ middle + 3.5, middle - 3.5 ]
      out[:paths][change.positive? ? :up : :down] <<
        "M#{RAIL_LEFT} #{brief_number(foot)}L#{RAIL_LEFT + 3.5} #{brief_number(tip)}L#{RAIL_LEFT + 7} #{brief_number(foot)}Z"
      amount = change.abs.to_s
      brief_text(out, amount, :inter_figures, CHANGE_SIZE, RAIL_LEFT + 12, baseline, change.positive? ? brief[:t][:ink2] : brief[:t][:muted])
      brief_text(out, "from #{before} last week", :inter_medium, CHANGE_SIZE, RAIL_LEFT + 16 + card_text_width(amount, :inter_figures, CHANGE_SIZE),
                 baseline, brief[:t][:muted])
    end

    # Next week's goal, then "Build log" and the mark before the builder's page.
    # The goal gets what the link leaves, and is cut to fit.
    def brief_footer(out, brief)
      brief_hline(out, LEFT, RIGHT, FOOTER_RULE, :strong)
      link = "openstage.dev/#{brief[:card].user.username}"
      brief_text(out, link, :inter_semibold, 16, RIGHT, FOOTER, brief[:t][:ink], anchor: :end)
      mark_x = RIGHT - card_text_width(link, :inter_semibold, 16) - 27
      out[:icons] << { kind: :mark, x: mark_x.round(1), y: (FOOTER - (brief_cap(:inter_semibold, 16) / 2) - 9).round(1), size: 18 }
      log_x = mark_x - 12 - card_text_width("BUILD LOG", :inter_bold, 10.5, 0.14)
      brief_text(out, "BUILD LOG", :inter_bold, 10.5, log_x, FOOTER, brief[:t][:muted], spacing: 0.14)
      brief_goal(out, brief, log_x - 32)
    end

    def brief_goal(out, brief, right)
      goal = brief[:wc].shows?("goal") ? CardText.clean(brief[:wc].next_goal) : ""
      return if goal.empty?

      brief_text(out, "NEXT WEEK", :inter_bold, 10.5, LEFT, FOOTER, brief[:t][:ink], spacing: 0.14)
      x = LEFT + card_text_width("NEXT WEEK", :inter_bold, 10.5, 0.14) + 14
      size = ((right - x) / [ card_text_width(goal, :newsreader_italic, 1), 1 ].max).clamp(16, 19)
      brief_text(out, card_cut_words(goal, :newsreader_italic, size, 0, right - x), :newsreader_italic, size, x, FOOTER, brief[:t][:ink])
    end
  end
end
