# The looks a week card can take. Each draws the same week facts; this list
# says what each is for, which partial draws it, which sections it has (the
# editor offers only those), which font families it draws with (the download
# embeds only those), and whether the builder can leave out the quiet days.
WeekCardTemplate = Data.define(:key, :name, :description, :sections, :families, :days_choice) do
  # The list is defined below the class, so it is reached through self.
  def self.all
    self::ALL
  end

  def self.keys
    all.map(&:key)
  end

  # The templates that draw any of these sections.
  def self.having(*sections)
    all.select { |template| sections.any? { |section| template.has?(section) } }
  end

  # The template for a stored style; Changelog for anything else.
  def self.find(key)
    all.find { |template| template.key == key } || all.first
  end

  def partial
    "week_cards/#{key}"
  end

  def has?(section)
    sections.include?(section)
  end

  def fonts
    CardText::FONTS.select { |font| families.include?(font[:family]) }
  end
end

# Picker order. The first is the default for new cards.
WeekCardTemplate::ALL = [
  WeekCardTemplate.new(
    key: "changelog", name: "Changelog", description: "Your week as release notes, for investors, clients and LinkedIn.",
    sections: %w[avatar name github totals compare activity projects headlines goal code],
    families: [ "Inter", "DM Mono" ], days_choice: true
  ),
  WeekCardTemplate.new(
    key: "star_chart", name: "Star Chart", description: "Your week as a night sky, with a persona named from it. Made for X.",
    sections: %w[avatar name github totals projects headlines persona history goal],
    families: [ "Newsreader", "DM Sans", "DM Mono" ], days_choice: true
  ),
  # Always seven columns, so the quiet days stay.
  WeekCardTemplate.new(
    key: "pixel_stage", name: "Pixel Stage", description: "Your week as an 8-bit game level, for game devs and fun weeks.",
    sections: %w[avatar name github building totals projects headlines goal],
    families: [ "Press Start 2P", "Pixelify Sans", "Tiny5" ], days_choice: false
  ),
  WeekCardTemplate.new(
    key: "timeline", name: "Timeline", description: "Your week as bars on a timeline, with the numbers around it.",
    sections: %w[avatar name github building streak totals compare projects headlines goal audience hours code repos],
    families: [ "DM Sans", "DM Mono" ], days_choice: true
  )
].freeze
