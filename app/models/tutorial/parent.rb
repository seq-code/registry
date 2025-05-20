module Tutorial::Parent
  class << self
    def hash
      {
        short_title: 'Higher taxa',
        title: 'Register higher taxa',
        prompt: 'New taxon above the rank of species',
        description: 'If you want to register the name of a genus, family, ' \
                     'order, class, or phylum, for which the type species ' \
                     '(or genus) is already validly published under the ' \
                     'SeqCode or under the ICNP rules, or currently under ' \
                     'revision in the SeqCode Registry',
        steps: []
      }
    end
  end
end
