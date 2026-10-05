class Name::PublicHistory
  # Only these recorded attributes appear in the public history.
  KEYS = %w[
    name rank syllabication status priority_date authority
    nomenclatural_status taxonomic_status proposal_kind corrigendum_from
    type_material type_accession proposed_in_id
  ].concat(Name::ETYMOLOGY_COLUMNS).freeze

  def initialize(name)
    @name = name
  end

  # Filter before paginating so each page contains public updates and link events only.
  def versions(page:)
    @name.versions
         .where(operation: 'update')
         .where(
           'EXISTS (SELECT 1 FROM jsonb_object_keys(versions.changeset) AS key WHERE key IN (?))',
           KEYS
         )
         .or(publication_versions)
         .order(created_at: :desc, id: :desc)
         .paginate(page: page, per_page: 25)
  end

  # Ordinary fields keep their [before, after] pairs. Etymology fields become
  # one pair of attribute snapshots for the view to render together.
  def changes_for(version)
    return publication_changes_for(version) if version.record_type == 'PublicationName'

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

  def publication_versions
    versions = Version.where(
      record_type: 'PublicationName',
      record_id: @name.publication_names.with_deleted.select(:id)
    )
    # A nil side marks a deletion or restoration; changing the deletion date
    # alone does not change whether the publication is linked.
    versions.where(operation: 'create').or(
      versions.where(operation: 'update').where(
        "changeset -> 'deleted_at' -> 0 = 'null'::jsonb OR " \
        "changeset -> 'deleted_at' -> 1 = 'null'::jsonb"
      )
    )
  end

  def publication_changes_for(version)
    @publication_ids ||= @name.publication_names.with_deleted.pluck(:id, :publication_id).to_h
    publication_id = @publication_ids.fetch(version.record_id)
    linked = version.operation == 'create' || version.changeset['deleted_at'].last.nil?

    if linked
      { 'pub_linked' => [nil, publication_id] }
    else
      { 'pub_unlinked' => [publication_id, nil] }
    end
  end

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
