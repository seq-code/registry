class TaggingService::LocalBackend
  include TaggingService::Helpers

  def propose(_name)
    raise TaggingService::Error, 'Local backend not yet implemented'
  end
end
