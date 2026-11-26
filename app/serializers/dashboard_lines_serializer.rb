# A project's numbers on the dashboard (Projects::Lines), as a click on its
# row brings them in: its name and colour, its page and Edit, and a line per
# number with where it comes from and its one control. A switch saves the
# way the project's own view saves it (Projects::NumbersController,
# Projects::PinsController); a step leads to the page that sets the number
# up, or to Pro. The first step that sets a number up is the filled one.
class DashboardLinesSerializer < ApplicationSerializer
  include Rails.application.routes.url_helpers

  # lines: a Projects::Lines; color_class: its colour on the stage, nil
  # without one.
  def initialize(lines, color_class:)
    @lines = lines
    @repo = lines.repo
    @color_class = color_class
  end

  def attributes
    filled = false
    lines = @lines.all.map do |line|
      control = control_of(line, filled: filled)
      filled ||= control[:filled]
      { key: line.key, name: name_of(line), state: words_of(line), sep: line.key == "pin", control: control }
    end
    { id: @repo.id, name: @repo.name, color_class: @color_class, page: project_page_path(@repo.user.username, @repo.name),
      edit: edit_project_path(@repo), lines: lines }
  end

  private

  def name_of(line)
    line.key == "pin" ? "Pinned" : Progress::Numbers.find(line.key).label
  end

  def words_of(line)
    case line.state
    when :switch then line.key == "pin" ? "A colour and a card on your stage" : "From #{source_of(line.key)}"
    when :waiting then "No visit from #{@repo.site_host} yet"
    when :set_up then "Not counted yet"
    when :slot then "Free counts #{Progress::Numbers.find(line.key).word} for one project"
    when :mine then "From Stripe. On Free only you see it."
    when :full then "#{ProgressChart::Palette::SIZE} projects are pinned: unpin one first"
    end
  end

  def source_of(key)
    case key
    when "commits" then "GitHub"
    when "mrr", "customers" then "Stripe"
    else @repo.site_host
    end
  end

  # kind: "switch", "link" or "pro". A link's filled: the first that sets a
  # number up, unless one before it is.
  def control_of(line, filled:)
    case line.state
    when :switch, :full then switch_of(line)
    when :mine then { kind: "pro", filled: false }
    when :slot then link("Go Pro", pricing_path, "Go Pro to set up #{Progress::Numbers.find(line.key).word} for #{@repo.name}", filled: false)
    else set_up_of(line, filled: !filled)
    end
  end

  def switch_of(line)
    pin = line.key == "pin"
    { kind: "switch", on: line.on, dead: line.dead, path: pin ? project_pin_path(@repo) : project_numbers_path(@repo), number: (line.key unless pin),
      aria: pin ? "Pin #{@repo.name} on your stage" : "Show #{name_of(line)} for #{@repo.name}", filled: false }
  end

  def set_up_of(line, filled:)
    case [ line.key, line.state ]
    in [ "visits", :waiting ] then link("Continue setup", site_visits_setup_path(project: @repo.id), "Continue setting up site visits for #{@repo.name}", filled: filled)
    in [ "visits", _ ] then link("Set up site visits", site_visits_setup_path(project: @repo.id), "Set up site visits for #{@repo.name}", filled: filled)
    else link("Set up MRR", mrr_path, "Set up MRR for #{@repo.name}", filled: filled)
    end
  end

  # Call 2 of the plan: Settings' Revenue panel until Stripe takes a key,
  # then the project's own view with its products open.
  def mrr_path
    @lines.stripe_ready? ? edit_project_path(@repo, revenue: "open", anchor: "revenue") : settings_path(tab: "integrations", project: @repo.id, anchor: "revenue")
  end

  def link(label, path, aria, filled:)
    { kind: "link", label: label, path: path, aria: aria, filled: filled }
  end
end
