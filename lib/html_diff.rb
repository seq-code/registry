require 'diff/lcs'

module HtmlDiff
  TOKEN = /<[^>]*>|\s+|[^<\s]+/
  TAG = /\A</
  CLASSES = { 'del' => 'text-danger', 'ins' => 'text-success' }.freeze

  # Returns [before_html, after_html]: each side's own HTML with its changed
  # text wrapped in <del> or <ins>. Tags are compared but never wrapped, so each
  # side keeps its own well-formed markup. The result is not sanitized. For an
  # E. coli description edit, '<div>A gut bacterium</div>' ->
  # '<div>A commensal gut bacterium</div>' gives
  # ['<div>A gut bacterium</div>', '<div>A <ins class="text-success">commensal </ins>gut bacterium</div>'].
  def self.diff(before, after)
    changes = Diff::LCS.sdiff(tokens(before), tokens(after))
    [
      render(changes.filter_map { |c| [c.old_element, c.action != '='] if c.old_element }, 'del'),
      render(changes.filter_map { |c| [c.new_element, c.action != '='] if c.new_element }, 'ins')
    ]
  end

  def self.tokens(html)
    html.to_s.scan(TOKEN)
  end

  # Wrap each run of changed text tokens, absorbing unchanged whitespace between
  # two changed runs so an edited phrase is marked as one.
  def self.render(tokens, tag)
    runs = tokens.chunk_while { |a, b| a[1] == b[1] && text?(a[0]) == text?(b[0]) }.to_a
    runs.each_with_index do |run, index|
      next unless index.positive? && index < runs.size - 1 && run.all? { |t, changed| !changed && t.match?(/\A\s+\z/) }

      before, after = runs[index - 1], runs[index + 1]
      run.each { |token| token[1] = true } if before.all? { |t, c| c && text?(t) } && after.all? { |t, c| c && text?(t) }
    end
    runs.flatten(1).chunk_while { |a, b| a[1] == b[1] && text?(a[0]) == text?(b[0]) }.map do |run|
      html = run.map(&:first).join
      run.first[1] && text?(run.first[0]) && html.match?(/\S/) ? %(<#{tag} class="#{CLASSES[tag]}">#{html}</#{tag}>) : html
    end.join
  end

  def self.text?(token)
    !token.match?(TAG)
  end
end
