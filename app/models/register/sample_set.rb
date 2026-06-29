module Register::SampleSet
  def sample_set
    @sample_set ||= RegisterSampleSet.new(self)
  end
end
