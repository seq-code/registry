module Genome::SampleSet
  def sample_set
    @sample_set ||= GenomeSampleSet.new(self, source_hash)
  end
end

class GenomeSampleSet < SampleSet
  attr :genome, :source_hash
  def initialize(genome, source_hash)
    @genome = genome
    @source_hash = source_hash
    @source_hash ||= {}
  end

  def source_object
    genome
  end

  def samples
    @samples ||=
      source_hash[:samples]&.map { |k, v| GenomeSample.new(k, v) } || []
  end

  def retrieved_at
    @source_hash[:retrieved_at]
  end

  def extra_biosamples
    return [] if empty?

    @source_extra_biosamples ||=
      %i[derived_from sample_derived_from].map do |attribute|
        next unless attr = unique_attributes[attribute]

        attr.map do |i|
          i.value.gsub(/.*: */, '').gsub(/[\.]/, '').split(/ *,(?: and)? */)
        end
      end.flatten.compact.uniq - known_biosamples
  end
end

