module WeekCardBriefHelper
  # How big the Brief can set things: the largest lead, at the largest row type,
  # that leaves the whole week above the footer. The rows are measured first,
  # so the lead knows how much room it has.
  module Fit
    TIERS = [
      { size: 17, pad: 10, quiet: 8, lead_min: 52 },
      { size: 16.5, pad: 9, quiet: 7, lead_min: 46 },
      { size: 16, pad: 8, quiet: 6, lead_min: 40 },
      { size: 15.5, pad: 7, quiet: 5, lead_min: 34 },
      { size: 15, pad: 6, quiet: 4, lead_min: 28 }
    ].freeze
    LEAD_MAX = 68

    def brief_fit(brief)
      leads = Hash.new { |plans, size| plans[size] = brief_lead_plan(brief, size) }
      fit = TIERS.lazy.filter_map { |tier| brief_fit_tier(brief, tier, leads) }.first || brief_squeeze(brief, leads)
      brief_cut_rows(brief, fit)
    end

    def brief_fit_tier(brief, tier, leads)
      plans = brief[:rows].map { |row| brief_row_plan(brief, row, tier) }
      need = plans.sum { |plan| plan[:h] }
      size = LEAD_MAX.downto(tier[:lead_min]).find { |s| leads[s] && leads[s][:list_top] + need <= FOOTER_RULE }
      { tier: tier, plans: plans, lead: leads[size] } if size
    end

    # Nothing fits: the lead shrinks to 22px at the smallest rows, and a lead
    # with no break that fits (a run of ideographs) is cut on one line rather
    # than run into the rail.
    def brief_squeeze(brief, leads)
      tier = TIERS.last
      lead = 28.downto(22).lazy.filter_map { |size| leads[size] }.first ||
             brief_lead_plan(brief, 28, [ card_cut_to_width(brief[:card].lead.text, :newsreader_display, 28, -0.006, MAIN_RIGHT - LEFT) ])
      { tier: tier, plans: brief[:rows].map { |row| brief_row_plan(brief, row, tier) }, lead: lead }
    end

    # The last check: while the rows still run past the footer, the wrapped row
    # with the most lines (then the longest words) is cut to one line.
    def brief_cut_rows(brief, fit)
      plans = fit[:plans]
      while fit[:lead][:list_top] + plans.sum { |plan| plan[:h] } > FOOTER_RULE
        wrapped = plans.each_index.select { |i| plans[i][:lines].to_a.size > 1 }
        break if wrapped.empty?

        i = wrapped.max_by { |k| [ plans[k][:lines].size, plans[k][:row][:text].length ] }
        plans[i] = brief_row_plan(brief, plans[i][:row], fit[:tier], one_line: true)
      end
      fit
    end

    def brief_lead_plan(brief, size, forced = nil)
      spacing = size >= 40 ? -0.012 : -0.006
      lines = forced || card_balance(brief[:card].lead.text, :newsreader_display, size, spacing, MAIN_RIGHT - LEFT, size >= 44 ? 2 : 3,
                                     strict: size > 34)
      return unless lines

      first = FLY + 16 + brief_cap(:newsreader_display, size)
      step = (size * 1.06).round(1)
      last = first + ((lines.size - 1) * step)
      av_top = (last + (SERIF_DESCENT * size) + 11).round
      { size: size, spacing: spacing, lines: lines, first: first, step: step, last: last, av_top: av_top,
        list_top: av_top + (brief[:byline] ? AVATAR + 16 : 20) }
    end

    def brief_row_plan(brief, row, tier, one_line: false)
      case row[:kind]
      when :quiet
        cap = brief_cap(:newsreader_italic, tier[:size] - 1.5)
        { row: row, kind: :quiet, size: tier[:size] - 1.5, cap: cap, h: (2 * tier[:quiet]) + cap.round + 8 }
      when :generated
        first = tier[:pad] + brief_cap(:newsreader_text_regular, tier[:size])
        { row: row, kind: :generated, size: tier[:size], first: first, h: (first + (SERIF_DESCENT * tier[:size]) + tier[:pad]).round }
      else brief_worded_plan(brief, row, tier, one_line)
      end
    end

    # The builder's words, balanced over up to three lines, over a line with
    # the tag on the left and the split by project on the right.
    def brief_worded_plan(brief, row, tier, one_line)
      size, face = tier[:size], row[:generated] ? :newsreader_text_regular : :newsreader_text
      lines = (card_balance(row[:text], face, size, 0, brief[:measure], 3) unless one_line) ||
              [ card_cut_words(row[:text], face, size, 0, brief[:measure]) ]
      step = (size * 1.27).round(1)
      first = tier[:pad] + brief_cap(face, size)
      last = first + ((lines.size - 1) * step)
      meta = row[:chips].any? || row[:tag] ? last + 7 + brief_cap(:inter_medium, 12) : nil
      { row: row, kind: :worded, face: face, size: size, lines: lines, step: step, first: first, meta: meta,
        h: ((meta ? meta + 3 : last + (SERIF_DESCENT * size)) + tier[:pad]).round }
    end

    # Spare room goes to the rows, worded rows two shares and the slim ones one,
    # each up to a cap; then whole pixels that never add up past the room.
    def brief_heights(fit)
      plans = fit[:plans]
      need = plans.sum { |plan| plan[:h] }
      extra = brief_spare(plans, FOOTER_RULE - fit[:lead][:list_top] - need)
      heights = plans.each_index.map { |i| (plans[i][:h] + extra[i]).floor }
      leftover = (need + extra.sum).floor - heights.sum
      order = plans.each_index.sort_by { |i| [ -(plans[i][:h] + extra[i] - heights[i]), i ] }
      order.first(leftover).each { |i| heights[i] += 1 }
      heights
    end

    def brief_spare(plans, spare)
      shares = plans.map { |plan| plan[:kind] == :worded ? 2 : 1 }
      caps = plans.map { |plan| plan[:kind] == :worded ? 18 : 8 }
      extra = Array.new(plans.size, 0.0)
      4.times do
        open = extra.each_index.map { |i| extra[i] < caps[i] ? shares[i] : 0 }
        break if spare <= 0.5 || open.sum.zero?

        unit = spare / open.sum
        extra.each_index.select { |i| open[i].positive? }.each do |i|
          add = [ caps[i] - extra[i], unit * open[i] ].min
          extra[i] += add
          spare -= add
        end
      end
      extra
    end
  end
end
