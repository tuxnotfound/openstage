module WeekCardBriefHelper
  # The Brief's byline, an author block beside the avatar: "By Tux · Openstage
  # Pro" over the GitHub handle and how long they have been at it. Pro is
  # spelled out as the plan it is, so it never reads as a self-awarded title.
  module Byline
    # The GitHub mark (16px octicon): the handle is the account the page is built from.
    GITHUB_MARK = "M8 0C3.58 0 0 3.58 0 8c0 3.54 2.29 6.53 5.47 7.59.4.07.55-.17.55-.38 0-.19-.01-.82-.01-1.49-2.01.37-2.53-.49-2.69-.94-.09-.23-.48-.94" \
                  "-.82-1.13-.28-.15-.68-.52-.01-.53.63-.01 1.08.58 1.23.82.72 1.21 1.87.87 2.33.66.07-.52.28-.87.51-1.07-1.78-.2-3.64-.89-3.64-3.95 0" \
                  "-.87.31-1.59.82-2.15-.08-.2-.36-1.02.08-2.12 0 0 .67-.21 2.2.82.64-.18 1.32-.27 2-.27.68 0 1.36.09 2 .27 1.53-1.04 2.2-.82 2.2-.82" \
                  ".44 1.1.16 1.92.08 2.12.51.56.82 1.27.82 2.15 0 3.07-1.87 3.75-3.65 3.95.29.25.54.73.54 1.48 0 1.07-.01 1.93-.01 2.2 0 .21.15.46" \
                  ".55.38A8.013 8.013 0 0016 8c0-4.42-3.58-8-8-8z".freeze
    NAME_SIZE = 13.5
    HANDLE_SIZE = 12

    def brief_byline?(card)
      wc = card.week_card
      brief_avatar?(card) || wc.shows?("name") || brief_handle(card).present? || brief_since(card).present?
    end

    def brief_avatar?(card)
      card.week_card.shows?("avatar") && card.user.avatar_url.present?
    end

    def brief_byline(out, brief, top)
      card = brief[:card]
      out[:avatar] = { x: LEFT, y: top, size: AVATAR, href: card.user.avatar_url } if brief_avatar?(card)
      x = brief_avatar?(card) ? LEFT + AVATAR + 11 : LEFT
      name = card.week_card.shows?("name")
      second = brief_handle(card).present? || brief_since(card).present?
      # One line sits level with the avatar's middle; two share its height.
      middle = top + (AVATAR / 2.0)
      brief_name_line(out, brief, x, second ? top + 14.5 : middle + (brief_cap(:inter_medium, NAME_SIZE) / 2)) if name
      brief_handle_line(out, brief, x, name ? top + 31 : middle + (brief_cap(:inter_medium, HANDLE_SIZE) / 2)) if second
    end

    def brief_name_line(out, brief, x, baseline)
      t, user = brief[:t], brief[:card].user
      plan = user.pro? ? 14 + card_text_width("·", :inter_medium, NAME_SIZE) + card_text_width("Openstage Pro", :inter_medium, NAME_SIZE) : 0
      brief_text(out, "By", :inter_medium, NAME_SIZE, x, baseline, t[:muted])
      x += card_text_width("By ", :inter_medium, NAME_SIZE)
      name = CardText.clean(user.display_name).presence || user.username
      name = card_cut_to_width(name, :inter_semibold, NAME_SIZE, 0, MAIN_RIGHT - x - plan)
      brief_text(out, name, :inter_semibold, NAME_SIZE, x, baseline, t[:ink])
      return unless user.pro?

      x += card_text_width(name, :inter_semibold, NAME_SIZE) + 7
      brief_text(out, "·", :inter_medium, NAME_SIZE, x, baseline, t[:muted])
      brief_text(out, "Openstage Pro", :inter_medium, NAME_SIZE, x + card_text_width("·", :inter_medium, NAME_SIZE) + 7, baseline, t[:muted])
    end

    def brief_handle_line(out, brief, x, baseline)
      t, handle, since = brief[:t], brief_handle(brief[:card]), brief_since(brief[:card])
      if handle
        out[:icons] << { kind: :github, x: x.round(1), y: (baseline - (brief_cap(:inter_medium, HANDLE_SIZE) / 2) - 6).round(1), size: 12 }
        handle = card_cut_to_width(handle, :inter_medium, HANDLE_SIZE, 0, MAIN_RIGHT - x - 17)
        brief_text(out, handle, :inter_medium, HANDLE_SIZE, x + 17, baseline, t[:ink2])
        x += 17 + card_text_width(handle, :inter_medium, HANDLE_SIZE)
      end
      return unless since

      if handle
        brief_text(out, "·", :inter_medium, HANDLE_SIZE, x + 7, baseline, t[:muted])
        x += 14 + card_text_width("·", :inter_medium, HANDLE_SIZE)
      end
      brief_text(out, card_cut_words(since, :inter_medium, HANDLE_SIZE, 0, MAIN_RIGHT - x), :inter_medium, HANDLE_SIZE, x, baseline, t[:muted])
    end

    def brief_handle(card)
      "@#{card.user.github_username}" if card.week_card.shows?("github") && card.user.github_username.present?
    end

    def brief_since(card)
      building = card.extras.building
      "Building in public since #{building.since.strftime('%B %Y')}" if card.week_card.shows?("building") && building
    end
  end
end
