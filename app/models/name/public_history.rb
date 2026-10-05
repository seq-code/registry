class Name::PublicHistory
  def initialize(name)
    @name = name
  end

  def events(page:)
    @name.history_events.order(created_at: :desc, id: :desc)
         .paginate(page: page, per_page: 25)
  end

  def changes_for(event)
    case event.kind
    when 'publication_linked'
      { 'pub_linked' => [nil, event.data.fetch('publication_id')] }
    when 'publication_unlinked'
      { 'pub_unlinked' => [event.data.fetch('publication_id'), nil] }
    when 'attributes_changed'
      attribute_changes_for(event)
    end
  end

  private

  # Ordinary fields keep their [before, after] pairs. Etymology fields become
  # one pair of attribute snapshots for the view to render together.
  def attribute_changes_for(event)
    changes = event.data.dup
    etymology = changes.extract!(*Name::History::ETYMOLOGY_ATTRIBUTES)
    if etymology.any?
      changes['etymology'] = etymology_snapshots(etymology, changes['name'])
    end
    # Etymology snapshots include unchanged companion values too.
    changes.reject! { |_, values| values.first == values.last }
    changes
  end

  # Include the name because full_etymology derives the :xx particle from its
  # last word.
  def etymology_snapshots(etymology, names)
    before_name, after_name = names || [@name.name, @name.name]
    before_attributes = etymology.transform_values(&:first)
    after_attributes = etymology.transform_values(&:last)

    [
      before_attributes.merge('name' => before_name),
      after_attributes.merge('name' => after_name)
    ]
  end
end
