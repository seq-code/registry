class CollectionSampleSet < RegisterSampleSet
  attr :collection

  def initialize(collection)
    @collection = collection
  end

  def source_object
    collection
  end

  def type_genomes
    @type_genomes ||= collection.map(&:type_genomes).flatten.uniq
  end
end
