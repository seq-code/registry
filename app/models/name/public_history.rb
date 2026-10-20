class Name::PublicHistory
  # Only these recorded attributes appear in the public history.
  NAME_KEYS = %w[
    name rank syllabication status priority_date authority
    nomenclatural_status taxonomic_status proposal_kind corrigendum_from corrigendum_kind
    nomenclatural_type_type nomenclatural_type_id
    proposed_in_id corrigendum_in_id assigned_in_id
    parent_id correct_name_id basonym_id redirect_id genome_id genome_strain
    ncbi_taxonomy lpsn_url gtdb_accession algaebase_species algaebase_taxonomy
    wikidata_item wikispecies_entry
  ].concat(Name::ETYMOLOGY_COLUMNS).freeze
  # unlinked_at is shown as whether the publication or placement is linked.
  PUBLICATION_NAME_KEYS = %w[unlinked_at emends not_valid_proposal].freeze
  # Only these rich texts of the name appear in the public history.
  RICH_TEXT_NAMES = %w[description etymology_text].freeze
  PLACEMENT_KEYS = %w[unlinked_at parent_id incertae_sedis publication_id preferred].freeze

  def initialize(name)
    @name = name
  end

  # Load all histories and filter displayable changes in Ruby before pagination.
  # Each version's record is loaded up front to label link changes.
  def versions(page:)
    name_versions.or(publication_versions).or(placement_versions).or(rich_text_versions)
                 .includes(:record, :user)
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
    when 'Placement'
      placement_changes_for(version)
    when 'ActionText::RichText'
      rich_text_changes_for(version)
    else
      raise ArgumentError, "Unsupported public history record type: #{version.record_type}"
    end
  end

  private

  def name_versions
    @name.versions.where(operation: 'update')
  end

  # Group etymology and polymorphic type attributes before removing unchanged
  # companions, so each side retains the context needed to render it.
  def name_changes_for(version)
    changes = version.changeset.slice(*NAME_KEYS)
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

  def rich_text_versions
    Version.where(
      record_type: 'ActionText::RichText',
      record_id: ActionText::RichText.where(
        record: @name, name: RICH_TEXT_NAMES
      ).select(:id)
    )
  end

  # A rich text version is shown as a change of the name's attribute it holds,
  # found in the changeset of a created or deleted rich text, or else on the
  # rich text itself:
  #   { 'description' => [nil, '<div>A gut bacterium</div>'] }
  def rich_text_changes_for(version)
    body = version.changeset['body']
    attribute = version.changeset['name']&.compact&.first || version.record&.name
    return {} unless body && body.first != body.last && RICH_TEXT_NAMES.include?(attribute)

    { attribute => body }
  end

  def publication_versions
    Version.where(
      record_type: 'PublicationName', record_id: @name.publication_names.select(:id)
    )
  end

  def publication_changes_for(version)
    link_record_changes(version, PUBLICATION_NAME_KEYS)
  end

  def placement_versions
    Version.where(record_type: 'Placement', record_id: @name.placements.select(:id))
  end

  def placement_changes_for(version)
    link_record_changes(version, PLACEMENT_KEYS)
  end

  # Linking a record is a create and unlinking is an update of unlinked_at, so
  # both are shown as a change of 'linked'. A creation also lists each
  # attribute it was added with that has a value:
  #   { 'linked' => [false, true], 'parent_id' => [nil, 2], 'incertae_sedis' => [nil, true] }
  # Updates show only the changed attributes:
  #   { 'linked' => [true, false], 'emends' => [true, false] }
  def link_record_changes(version, keys)
    changes = version.changeset.slice(*keys)

    case version.operation
    when 'create'
      # unlinked_at is shown as 'linked'; skip attributes the link was created
      # without, such as the default false roles.
      added = changes.except('unlinked_at').reject { |_, (_, after)| after.blank? }
      { 'linked' => [false, true] }.merge(added)
    when 'update'
      link_changes(changes)
    else
      {}
    end
  end

  # Replace an unlinked_at change with a 'linked' change listed first:
  #   { 'unlinked_at' => [nil, '2026-10-01T12:00:00Z'], 'emends' => [true, false] }
  #     => { 'linked' => [true, false], 'emends' => [true, false] }
  def link_changes(changes)
    unlinked_at = changes.delete('unlinked_at')
    return changes unless unlinked_at

    # A nil unlinked_at means the record is linked.
    linked = unlinked_at.map(&:nil?)
    # Changing the timestamp of an already unlinked record is not a link change.
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
