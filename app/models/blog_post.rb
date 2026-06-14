# Lightweight, file-based blog. Each post is a registry entry here plus a body
# partial in app/views/blog/posts/_<slug-with-underscores>.html.erb.
# No database, no extra gems — version-controlled, fast, and fully indexable.
class BlogPost
  POSTS = [
    {
      slug: "why-one-link-beats-ten",
      title: "Why one link beats ten for building in public",
      description: "Your build-in-public proof is scattered across GitHub, threads, and forums. Here's why consolidating it into a single link compounds.",
      published_on: Date.new(2026, 6, 5),
      reading_minutes: 4
    },
    {
      slug: "turn-github-commits-into-a-story",
      title: "How Openstage turns your GitHub commits into a story",
      description: "Commits show what changed, not why it mattered. Here's how Openstage layers milestones and notes on top of your GitHub activity.",
      published_on: Date.new(2026, 6, 11),
      reading_minutes: 5
    }
  ].freeze

  attr_reader :slug, :title, :description, :published_on, :reading_minutes

  def self.all
    POSTS.map { |attrs| new(attrs) }.sort_by(&:published_on).reverse
  end

  def self.find(slug)
    attrs = POSTS.find { |p| p[:slug] == slug }
    attrs && new(attrs)
  end

  def initialize(attrs)
    @slug             = attrs[:slug]
    @title            = attrs[:title]
    @description      = attrs[:description]
    @published_on     = attrs[:published_on]
    @reading_minutes  = attrs[:reading_minutes]
  end

  def to_param
    slug
  end

  # Body partial path, e.g. "blog/posts/why_one_link_beats_ten"
  def body_partial
    "blog/posts/#{slug.tr('-', '_')}"
  end
end
