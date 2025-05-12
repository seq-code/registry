module Register::SampleSet
  def sample_set
    @sample_set ||= RegisterSampleSet.new(self)
  end
end

class RegisterSampleSet < SampleSet
  attr :register, :genome_sample_sets

  def initialize(register)
    @register = register
  end

  def source_object
    register
  end

  def genome_sample_sets
    @genome_sample_sets ||=
      register.type_genomes.uniq.map(&:sample_set).compact
  end

  def samples
    @samples ||= genome_sample_sets.map(&:samples).flatten
  end
end

