# Lightweight, file-based blog. Each post is a registry entry here plus a body
# partial in app/views/blog/posts/_<slug-with-underscores>.html.erb.
# No database, no extra gems — version-controlled, fast, and fully indexable.
# chart: "username/project", a project page whose commits the post's share
# card draws under its title; leave it out for a post about no one project.
class BlogPost
  POSTS = [
    {
      slug: "rebuilt-around-projects",
      title: "Product Hunt sent about 150 visits and no signups. So I rebuilt Openstage around projects.",
      description: "The launch page showed a commit log. Now each project has a page of its own, with visits to its website beside its commits, and Openstage has numbers to reach by November 30.",
      published_on: Date.new(2026, 11, 4),
      reading_minutes: 3,
      chart: "tuxnotfound/openstage"
    },
    {
      slug: "rebuilt-on-itself",
      title: "My build-in-public tool showed I had quit. So I rebuilt it on itself.",
      description: "Openstage's own timeline showed 82 days of nothing from its founder. What the page exposed, what was broken underneath, and what the relaunch changed, with the honest numbers.",
      published_on: Date.new(2026, 10, 6),
      reading_minutes: 4,
      chart: "tuxnotfound/openstage"
    },
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

  attr_reader :slug, :title, :description, :published_on, :reading_minutes, :chart

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
    @chart            = attrs[:chart]
  end

  def to_param
    slug
  end

  # Body partial path, e.g. "blog/posts/why_one_link_beats_ten"
  def body_partial
    "blog/posts/#{slug.tr('-', '_')}"
  end
end
