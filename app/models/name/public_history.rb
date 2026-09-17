class Name::PublicHistory
  # Only these recorded attributes appear in the public history.
  KEYS = %w[
    name rank syllabication status priority_date authority
    nomenclatural_status taxonomic_status proposal_kind corrigendum_from
    type_material type_accession
  ].concat(Name::ETYMOLOGY_COLUMNS).freeze

  def initialize(name)
    @name = name
  end

  # Filter before paginating so each page contains public updates only.
  def versions(page:)
    @name.versions
         .where(operation: 'update')
         .where(
           'EXISTS (SELECT 1 FROM jsonb_object_keys(versions.changeset) AS key WHERE key IN (?))',
           KEYS
         )
         .order(created_at: :desc, id: :desc)
         .paginate(page: page, per_page: 25)
  end

  # Ordinary fields keep their [before, after] pairs. Etymology fields become
  # one pair of attribute snapshots for the view to render together.
  def changes_for(version)
    changes = version.changeset.slice(*KEYS)
    etymology = changes.extract!(*Name::ETYMOLOGY_COLUMNS)
    if etymology.any?
      changes['etymology'] = etymology_snapshots(etymology, changes['name'])
    end
    # versioned_together records unchanged companion values too.
    changes.reject! { |_, values| values.first == values.last }
    changes
  end

  private

  # Include the name because full_etymology derives the :xx particle from its
  # last word. Older versions without a name pair use the current name.
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
