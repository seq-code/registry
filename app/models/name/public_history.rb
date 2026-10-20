class Name::PublicHistory
  # Only these recorded attributes appear in the public history.
  KEYS = %w[
    name rank syllabication status priority_date authority
    nomenclatural_status taxonomic_status proposal_kind corrigendum_from corrigendum_kind
    type_material type_accession nomenclatural_type_type nomenclatural_type_id
    proposed_in_id corrigendum_in_id assigned_in_id
    parent_id correct_name_id basonym_id redirect_id genome_id genome_strain
    ncbi_taxonomy lpsn_url gtdb_accession algaebase_species algaebase_taxonomy
    wikidata_item wikispecies_entry
  ].concat(Name::ETYMOLOGY_COLUMNS).freeze

  def initialize(name)
    @name = name
  end

  # Load both histories and filter displayable changes in Ruby before pagination.
  def versions(page:)
    name_versions.or(publication_versions)
                 .order(created_at: :desc, id: :desc)
                 .select { |version| changes_for(version).any? }
                 .paginate(page: page, per_page: 25)
  end

  def changes_for(version)
    case version.record_type
    when 'Name'
      name_changes_for(version)
    when 'PublicationName'
      publication_changes_for(version)
    else
      raise ArgumentError, "Unsupported public history record type: #{version.record_type}"
    end
  end

  def publication_id_for(version)
    @publication_ids ||= @name.publication_names.pluck(:id, :publication_id).to_h
    @publication_ids.fetch(version.record_id)
  end

  private

  def name_versions
    @name.versions.where(operation: 'update')
  end

  # Group etymology and polymorphic type attributes before removing unchanged
  # companions, so each side retains the context needed to render it.
  def name_changes_for(version)
    changes = version.changeset.slice(*KEYS)
    etymology = changes.extract!(*Name::ETYMOLOGY_COLUMNS)
    if etymology.any?
      changes['etymology'] = etymology_snapshots(etymology, changes['name'])
    end
    Name.reflect_on_all_associations(:belongs_to).select(&:polymorphic?).each do |reflection|
      reference = changes.extract!(reflection.foreign_type, reflection.foreign_key)
      next if reference.empty?

      types = reference.fetch(reflection.foreign_type, [nil, nil])
      ids = reference.fetch(reflection.foreign_key, [nil, nil])
      changes[reflection.name.to_s] = types.zip(ids)
    end
    # versioned_together records unchanged companion values too.
    changes.reject! { |_, values| values.first == values.last }
    changes
  end

  def publication_versions
    Version.where(
      record_type: 'PublicationName', record_id: @name.publication_names.select(:id)
    )
  end

  def publication_changes_for(version)
    return { 'linked' => [false, true] } if version.operation == 'create'
    return {} unless version.operation == 'update'

    changes = version.changeset.dup
    unlinked_at = changes.delete('unlinked_at')
    return changes unless unlinked_at

    # A nil unlinked_at means the publication is linked.
    linked = unlinked_at.map(&:nil?)
    return changes if linked.first == linked.last

    { 'linked' => linked }.merge(changes)
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
