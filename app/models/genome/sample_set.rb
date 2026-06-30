module Genome::SampleSet
  def sample_set
    @sample_set ||= GenomeSampleSet.new(self, source_hash)
  end
end
