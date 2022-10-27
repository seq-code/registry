module Tutorial::Batch
  class << self
    def hash
      {
        title: 'Batch upload of new names',
        prompt: 'New names from a single spreadsheet',
        description: 'If you want to upload up to 100 names described in a ' \
                     'spreadsheet template',
        steps: []
      }
    end
  end
end
