module WeekCardBriefHelper
  # The Brief's day list. Left is the story: the date as a calendar, the
  # builder's words and a status tag. Right is the code: the day's commits as a
  # count and a bar on one scale for the week, with the split by project
  # beneath. A day without the builder's words stays slim: its split stands
  # where the words would be, so its count shows once.
  module Days
    CHIP_GAP = 14

    def brief_days(out, brief, fit)
      top = fit[:lead][:list_top]
      brief_hline(out, LEFT, MAIN_RIGHT, top)
      if brief[:card].totals.commits.positive?
        brief_text(out, "COMMITS", :inter_bold, 10.5, MAIN_RIGHT, top - 8, brief[:t][:muted], spacing: 0.14, anchor: :end)
      end
      fit[:plans].zip(brief_heights(fit)).each_with_index do |(plan, height), i|
        brief_hline(out, LEFT, MAIN_RIGHT, top) if i.positive?
        plan[:kind] == :quiet ? brief_quiet_day(out, brief, plan, top, height) : brief_day(out, brief, plan, top + ((height - plan[:h]) / 2.0))
        top += height
      end
    end

    # Only what the card can see: no commits and nothing said. It never claims
    # the builder did nothing.
    def brief_quiet_day(out, brief, plan, top, height)
      baseline = top + (height / 2.0) + (plan[:cap] / 2)
      brief_date(out, brief, plan[:row], baseline, brief[:t][:muted], brief[:t][:muted])
      brief_text(out, "No commits", :newsreader_italic, plan[:size], TEXT_X, baseline, brief[:t][:muted])
    end

    def brief_day(out, brief, plan, origin)
      t, row = brief[:t], plan[:row]
      baseline = origin + plan[:first]
      brief_date(out, brief, row, baseline, row[:lead] ? t[:accent] : t[:ink2], row[:lead] ? t[:accent] : t[:muted])
      if plan[:kind] == :generated
        shown, more = brief_fold_chips(row[:chips], brief[:measure])
        brief_draw_chips(out, shown, more, TEXT_X, baseline, t[:generated], t[:generated])
      else
        brief_words(out, brief, plan, baseline, origin + plan[:meta].to_f)
      end
      brief_count(out, brief, plan, baseline)
    end

    # The weekday in small caps at the margin, the day of the month as a serif
    # numeral flush right in its own column, so the rows read as a calendar.
    # The lead's day takes the accent, echoing the fly title.
    def brief_date(out, brief, row, baseline, ink, weekday_ink)
      brief_text(out, row[:day].date.strftime("%a").upcase, :inter_semibold, 10.5, LEFT, baseline, weekday_ink, spacing: 0.12)
      brief_text(out, row[:day].date.day.to_s, :newsreader_text, 18, DATE_RIGHT, baseline, ink, anchor: :end)
    end

    # The tag opens the line under the words it describes; the split by project
    # sits flush right under the count it adds up to.
    def brief_words(out, brief, plan, baseline, meta)
      fill = plan[:row][:generated] ? brief[:t][:generated] : brief[:t][:ink]
      plan[:lines].each_with_index { |line, k| brief_text(out, line, plan[:face], plan[:size], TEXT_X, baseline + (k * plan[:step]), fill) }
      return unless plan[:meta]

      tag_end = plan[:row][:tag] ? brief_tag(out, brief, plan[:row][:tag], meta) : TEXT_X
      shown, more = brief_fold_chips(plan[:row][:chips], MAIN_RIGHT - (tag_end + (tag_end > TEXT_X ? 20 : 0)))
      brief_draw_chips(out, shown, more, MAIN_RIGHT - brief_chips_width(shown, more), meta, brief[:t][:ink2], brief[:t][:muted])
    end

    # Status, not the lead, so the secondary ink: Shipped filled, Published outlined.
    def brief_tag(out, brief, kind, meta)
      word = kind.upcase
      width = (card_text_width(word, :inter_bold, 9, 0.1) + 12).round
      top = (meta - (brief_cap(:inter_bold, 9) / 2) - 8).round
      if kind == "shipped"
        out[:paths][:tag_fill] << brief_round_rect(TEXT_X, top, width, 16, 3)
      else
        out[:paths][:tag_line] << brief_round_rect(TEXT_X + 0.5, top + 0.5, width - 1, 15, 3)
      end
      brief_text(out, word, :inter_bold, 9, TEXT_X + 6, top + 8 + (brief_cap(:inter_bold, 9) / 2),
                 kind == "shipped" ? brief[:t][:paper] : brief[:t][:ink2], spacing: 0.1)
      TEXT_X + width
    end

    # The bar's centre sits on the words' x-height middle, so count, bar and
    # words read as one line. The lead's bar takes the accent.
    def brief_count(out, brief, plan, baseline)
      day = plan[:row][:day]
      return unless day.total.positive?

      brief_text(out, day.total.to_s, :inter_figures, 13, COUNT_RIGHT, baseline, brief[:t][:ink], anchor: :end)
      top = (baseline - (SERIF_X_HEIGHT * plan[:size] / 2) - 2.5).round
      out[:paths][:tracks] << brief_round_rect(BAR_X, top, BAR_MAX, 5, 1)
      length = [ ((day.total.to_f / brief[:bar_scale]) * BAR_MAX).round, 2 ].max
      out[:paths][plan[:row][:lead] ? :lead_bar : :bars] << brief_round_rect(BAR_X, top, length, 5, 1)
    end

    # Long names give way first, a few characters at a time but never under 24,
    # so a cut name still says which project it is. Past that, the smallest
    # projects fold into "+N more".
    def brief_fold_chips(chips, room)
      shown = chips.map { |chip| chip.merge(label: chip[:name]) }
      [ 28, 24 ].each do |limit|
        break if brief_chips_width(shown, 0) <= room

        shown = chips.map { |chip| chip.merge(label: card_cut_name(chip[:name], limit)) }
      end
      shown = shown[0...-1] while shown.size > 1 && brief_chips_width(shown, chips.size - shown.size) > room
      [ shown, chips.size - shown.size ]
    end

    def brief_chips_width(chips, more)
      widths = chips.map { |chip| 12 + card_text_width(chip[:label], :inter_medium, 12) + 4 + card_text_width(chip[:n].to_s, :inter_medium, 12) }
      widths.sum + (CHIP_GAP * [ chips.size - 1, 0 ].max) + (more.positive? ? CHIP_GAP + card_text_width("+#{more} more", :inter_medium, 12) : 0)
    end

    # A 7px chip in the project's colour, the name, the count.
    def brief_draw_chips(out, chips, more, x, baseline, name_ink, count_ink)
      chips.each do |chip|
        out[:marks] << { x: x.round(1), y: (baseline - (brief_cap(:inter_medium, 12) / 2) - 3.5).round(1), color: card_project_color(chip[:slot]) }
        brief_text(out, chip[:label], :inter_medium, 12, x + 12, baseline, name_ink)
        x += 12 + card_text_width(chip[:label], :inter_medium, 12) + 4
        brief_text(out, chip[:n].to_s, :inter_medium, 12, x, baseline, count_ink)
        x += card_text_width(chip[:n].to_s, :inter_medium, 12) + CHIP_GAP
      end
      brief_text(out, "+#{more} more", :inter_medium, 12, x, baseline, count_ink) if more.positive?
    end
  end
end
