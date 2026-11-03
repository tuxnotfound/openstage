# Marks drawn inline beside a builder's accounts, in the window's Pick dates
# pill and on the chart's marks, so they take the text's colour in light and
# dark. Each is hidden from screen readers; the link or button beside it
# says what it is.
module IconsHelper
  BRANDS = {
    github: "M12 .297c-6.63 0-12 5.373-12 12 0 5.303 3.438 9.8 8.205 11.385.6.113.82-.258.82-.577 0-.285-.01-1.04-.015-2.04-3.338.724-4.042-1.61-4.042-1.61C4.422 18.07 3.633 17.7 3.633 17.7c-1.087-.744.084-.729.084-.729 1.205.084 1.838 1.236 1.838 1.236 1.07 1.835 2.809 1.305 3.495.998.108-.776.417-1.305.76-1.605-2.665-.3-5.466-1.332-5.466-5.93 0-1.31.465-2.38 1.235-3.22-.135-.303-.54-1.523.105-3.176 0 0 1.005-.322 3.3 1.23.96-.267 1.98-.399 3-.405 1.02.006 2.04.138 3 .405 2.28-1.552 3.285-1.23 3.285-1.23.645 1.653.24 2.873.12 3.176.765.84 1.23 1.91 1.23 3.22 0 4.61-2.805 5.625-5.475 5.92.42.36.81 1.096.81 2.22 0 1.606-.015 2.896-.015 3.286 0 .315.21.69.825.57C20.565 22.092 24 17.592 24 12.297c0-6.627-5.373-12-12-12",
    x: "M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-4.714-6.231-5.401 6.231H2.744l7.73-8.835L1.254 2.25H8.08l4.259 5.63zm-1.161 17.52h1.833L7.084 4.126H5.117z"
  }.freeze

  # name: :github or :x.
  def brand_icon(name, css: "size-3.5")
    tag.svg(tag.path(d: BRANDS.fetch(name)), class: css, viewBox: "0 0 24 24", fill: "currentColor", aria: { hidden: true })
  end

  def calendar_icon(css: "size-3.5")
    tag.svg(safe_join([ tag.rect(x: 3.5, y: 5, width: 17, height: 15, rx: 2.5), tag.path(d: "M3.5 10h17M8 3v4M16 3v4") ]),
            class: css, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 2, "stroke-linecap": "round", aria: { hidden: true })
  end

  # A flag for a milestone, a rocket for anything else shipped, a speech
  # bubble for what was published, by an entry's badge, as the chart's
  # script draws them (Marks.tsx); static, as .os-chart stretches every svg
  # inside it over the chart.
  MARKS = {
    milestone: "M3 1.5a.8.8 0 0 1 .8.8v.4h8.9c.5 0 .8.6.5 1L11.1 6.4l2.1 2.7c.3.4 0 1-.5 1H3.8v4.6a.8.8 0 0 1-1.6 0V2.3a.8.8 0 0 1 .8-.8Z",
    shipped: "M14.5 1.5c-3.4.2-6.3 1.8-8.3 4.6L4.6 8.4l3 3 2.3-1.6c2.8-2 4.4-4.9 4.6-8.3Zm-2.6 4a1.4 1.4 0 1 1-2.8 0 1.4 1.4 0 0 1 2.8 0ZM6.2 6.1 2.6 5.9 1 7.6l3.6.8ZM9.9 9.8l.2 3.6L8.4 15l-.8-3.6ZM4.1 11.1c-1.2.3-2 1.2-2.4 3.2 2-.4 2.9-1.2 3.2-2.4Z",
    published: "M3.5 2.5h9a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2H7.6L4.5 14v-2.5h-1a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2Z"
  }.freeze

  def mark_icon(badge, css: "size-[13px]")
    tag.svg(tag.path(d: MARKS.fetch(badge.to_sym), "fill-rule": "evenodd"), class: "#{css} static flex-none", viewBox: "0 0 16 16", fill: "currentColor",
                                                                           aria: { hidden: true })
  end

  def email_icon(css: "size-3.5")
    tag.svg(safe_join([ tag.rect(x: 3, y: 5, width: 18, height: 14, rx: 2), tag.path(d: "m3 7 9 6 9-6") ]),
            class: css, viewBox: "0 0 24 24", fill: "none", stroke: "currentColor", "stroke-width": 1.8, aria: { hidden: true })
  end
end
