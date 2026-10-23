# The line of a README that says what the project is: its first paragraph of
# prose, read as plain words. Headings, badges, pictures, HTML, lists, quotes
# and code are passed over, and Rails' default README says nothing.
module ReadmeLine
  LIMIT = 200
  RAILS_DEFAULT = /\AThis README would normally document/i
  NOT_PROSE = /\A(\#|\[!\[|!\[|<|>|\||```|~~~|[-*+]\s|\d+\.\s)/

  module_function

  def of(text)
    paragraph = text.to_s.split(/\r?\n\s*\r?\n/).map(&:strip).find { |block| prose?(block) }
    return if paragraph.nil?

    line = plain(paragraph.lines.map(&:strip).join(" "))
    return if line.match?(RAILS_DEFAULT) || !line.match?(/[[:alpha:]]{2}/)

    line.length > LIMIT ? "#{line[0, LIMIT].sub(/\s+\S*\z/, '')}…" : line
  end

  # A setext heading is a line of text over a line of = or -.
  def prose?(block)
    !block.match?(NOT_PROSE) && block.lines.none? { |line| line.strip.match?(/\A[=-]{3,}\z/) }
  end

  def plain(text)
    text.gsub(/!\[[^\]]*\]\([^)]*\)/, "")
        .gsub(/\[([^\]]*)\]\([^)]*\)/, '\1')
        .gsub(/<[^>]+>/, "")
        .gsub(/(\*\*|__|\*|_|`)(\S(?:.*?\S)?)\1/, '\2')
        .squish
  end
end
