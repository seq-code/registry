# Rich text lives in its own records, so version them like any other record.
Rails.application.config.to_prepare do
  ActionText::RichText.include(Versioned)
end
