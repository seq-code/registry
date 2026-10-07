require 'diff/lcs'

module TextDiff
  # Returns [unchanged, before_text, after_text] chunks. For an E. coli etymology
  # edit, 'of the colon' -> 'from the colon' gives:
  # [[false, 'of', 'from'], [true, ' the colon', ' the colon']].
  def self.chunks(before, after)
    changes = Diff::LCS.sdiff(before.to_s.scan(/\X/), after.to_s.scan(/\X/))
    # Group characters into unchanged/changed runs, combining additions and deletions.
    runs = changes.chunk { |change| change.action == '=' }.to_a
    # Absorb unchanged islands of up to two characters between edits; keep the ends.
    runs[1...-1].to_a.each { |run| run[0] = false if run[1].size <= 2 }
    # Merge the resulting runs into contiguous text chunks.
    runs.chunk_while { |a, b| a[0] == b[0] }.map do |group|
      chunk = group.flat_map(&:last)
      [group.first[0], chunk.map(&:old_element).compact.join,
       chunk.map(&:new_element).compact.join]
    end
  end
end
