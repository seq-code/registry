module Tutorial::Neotype
  class << self
    def hash
      {
        title: 'Register new type',
        prompt: 'New type for an existing taxon',
        description: 'If you want to register a different genome as the ' \
                     'material of an existing species or subspecies, or ' \
                     'want to register a different genus as the type name ' \
                     'of a taxon above the rank of genus',
        steps: []
      }
    end
  end
end
