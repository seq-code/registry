module Tutorial::Subspecies
  class << self
    def hash
      {
        short_title: 'Subspecies',
        title: 'Register subspecies',
        prompt: 'New subspecies from a previously described species',
        description: 'If you want to register a new subspecies from a ' \
                     'species that is already validly published under the ' \
                     'SeqCode or under the ICNP rules, or currently under ' \
                     'revision in the SeqCode Registry',
        steps: []
      }
    end
  end
end
