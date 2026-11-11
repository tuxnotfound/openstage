# The table under a chart filter's chart: a row per project (per page on
# analytics), a column per number, each cell the row's value over the window
# (and on analytics its change against the window before), and a row's box
# drawing it on the chart or not. On the builder's dashboard (manage) a row
# also has Edit, whether their page lists it, whether it is pinned there
# with a colour (pin_of), and the path that saves its switches: each cell's
# switch sets what visitors see (a value they do not see stays for the
# builder, in grey), or in its place Set up, where a project counts no site
# visits, or Paused, where Free counts another project's, each to the
# project's Site visits row. A project hidden from the page is in the
# dashboard's list of projects, not here. A project past the palette has no
# colour, so no box: it keeps its values, in grey, as it draws no line.
# Which rows the chart draws (Row#drawn?) and which cells list a value, a
# switch or a link (DrawService#cells) is the chart's to say; this only
# writes it. A builder's stage and dashboard (boxed_only) list the rows with
# a box alone; the stage names how many it leaves to its list of projects,
# under the cards (more), while the dashboard's list starts under the table.
class ProjectsTableSerializer < ApplicationSerializer
  include Rails.application.routes.url_helpers

  WIDE = 5
  # Where the stage's list of projects starts, which more leads to.
  MORE_ANCHOR = "more-projects".freeze

  # A pin's title: pinned, or not while every colour is taken (full), or not.
  # The dashboard's list of projects writes the same words.
  def self.pin_title(on:, full:)
    return "Pinned: it has a colour and a card on your stage. Click to unpin it." if on
    return "#{ProgressChart::Palette::SIZE} projects are pinned. Unpin one to pin this one." if full

    "Pin it to give it a colour and a card on your stage."
  end

  # chart: a Progress::ChartService or an Analytics::ReportService; changes:
  # whether each cell carries its change; manage: the builder's own table;
  # boxed_only: the stage's or the dashboard's table, of the rows with a box.
  def initialize(chart, changes: false, manage: false, boxed_only: false)
    @chart = chart
    @changes = changes
    @manage = manage
    @boxed_only = boxed_only
  end

  # columns: each number with its names, and the number it sits beside
  # (Progress::Numbers::Number#beside), nil for one with lines of its own:
  # the dashboard hides a cell at once while that number switches off.
  # more: the link to the rows left out, nil with none.
  def attributes
    { columns: @chart.columns.map { |number| { key: number.key, label: number.label, word: number.word, beside: number.beside } },
      rows: listed.map { |row| row_of(row) }, stack: stack, more: more }
  end

  private

  def listed
    @boxed_only ? @chart.rows.select(&:boxed?) : @chart.rows
  end

  # The breakpoint below which the table stacks, as on a phone (the stacked
  # variant): "md", or "lg" from WIDE columns on. Its name column takes 180
  # px at least, each number's 80 to 120 with its change or its switch, and
  # Your stage 76; at 768 px a panel holds 682 px, at 1024 px 909, so four
  # columns fit from md, and analytics' seven from lg.
  def stack
    @chart.columns.size + (@manage ? 1 : 0) >= WIDE ? "lg" : "md"
  end

  # color_class: the class its box wears; drawable: whether it has one; on:
  # whether the chart draws it.
  def row_of(row)
    { key: row.key, name: row.name, color_class: row.color_class, on: row.drawn?, drawable: row.boxed?,
      cells: @chart.cells(row).map { |cell| cell_of(cell, row) } }.merge(manage_parts(row.repo, row.rank))
  end

  # pick: the cell's switch, on while visitors see the number; nil without
  # one. link: what stands in its place (link_of).
  def cell_of(cell, row)
    { key: cell.number.key, value: (@chart.counts.written(cell.number, cell.value) if cell.value), shown: cell.shown, pick: cell.pick,
      link: (link_of(cell.link, row) if cell.link),
      change: (Progress::Change.of(cell.value, cell.previous)&.to_h if @changes && cell.shown) }
  end

  # Paused or Set up (Row#link), with its name for a screen reader, which
  # starts with the word on screen, and the project's Site visits row it
  # leads to, which says why and what to do. Both the island and the first
  # paint write these words.
  def link_of(link, row)
    text, label = link == :paused ? [ "Paused", "Paused: see why #{row.name}'s site visits do not count" ] : [ "Set up", "Set up #{row.name}'s site visits" ]
    { text: text, label: label, path: edit_project_path(row.repo, site: "open", anchor: "site-visits") }
  end

  # A project with no synced repo behind it has nothing to edit or save.
  def manage_parts(repo, rank)
    return { edit: nil, page: nil, pin: nil, switch: nil } unless @manage && repo

    { edit: edit_project_path(repo), page: { on: repo.included?, path: github_repo_path(repo) }, pin: pin_of(repo, rank),
      switch: project_numbers_path(repo) }
  end

  # Whether it is pinned to the stage: the projects with a colour are the
  # pinned ones, the busiest until the builder picks (Projects::PinService).
  # None for a project the stage does not show. Its words are the server's,
  # as for every switch the island draws.
  def pin_of(repo, rank)
    return unless repo.included? && rank

    on = ProgressChart::Palette.colored?(rank)
    { on: on, path: project_pin_path(repo), title: self.class.pin_title(on: on, full: colored_rows >= ProgressChart::Palette::SIZE) }
  end

  def colored_rows
    @colored_rows ||= @chart.rows.count { |row| row.rank && ProgressChart::Palette.colored?(row.rank) }
  end

  def more
    return if @manage

    left = @chart.rows.size - listed.size
    { text: "#{left} more #{'project'.pluralize(left)}", anchor: MORE_ANCHOR } if left.positive?
  end
end
