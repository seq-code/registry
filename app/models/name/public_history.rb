class Name::PublicHistory
  # Only these recorded attributes appear in the public history.
  NAME_KEYS = %w[
    name rank syllabication status priority_date authority
    nomenclatural_status taxonomic_status proposal_kind corrigendum_from corrigendum_kind
    nomenclatural_type_type nomenclatural_type_id
    proposed_in_id corrigendum_in_id assigned_in_id
    parent_id correct_name_id basonym_id redirect_id genome_strain
    ncbi_taxonomy lpsn_url gtdb_accession algaebase_species algaebase_taxonomy
    wikidata_item wikispecies_entry
  ].concat(Name::ETYMOLOGY_COLUMNS).freeze
  # deleted_at is shown as whether the publication or placement is linked.
  PUBLICATION_NAME_KEYS = %w[deleted_at emends not_valid_proposal].freeze
  # Only these rich texts of the name appear in the public history.
  RICH_TEXT_NAMES = %w[description etymology_text].freeze
  PLACEMENT_KEYS = %w[deleted_at parent_id incertae_sedis publication_id preferred].freeze

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

  # Group etymology and nomenclatural type attributes before removing unchanged
  # companions, so each side retains the context needed to render it.
  def name_changes_for(version)
    changes = version.changeset.slice(*NAME_KEYS)
    etymology = changes.extract!(*Name::ETYMOLOGY_COLUMNS)
    if etymology.any?
      changes['etymology'] = etymology_snapshots(etymology, changes['name'])
    end
    nomenclatural_type = changes.extract!('nomenclatural_type_type', 'nomenclatural_type_id')
    if nomenclatural_type.any?
      changes['nomenclatural_type'] = nomenclatural_type_references(nomenclatural_type)
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
      record_type: 'PublicationName', record_id: @name.all_publication_names.select(:id)
    )
  end

  def publication_changes_for(version)
    link_record_changes(version, PUBLICATION_NAME_KEYS)
  end

  def placement_versions
    Version.where(record_type: 'Placement', record_id: @name.all_placements.select(:id))
  end

  def placement_changes_for(version)
    link_record_changes(version, PLACEMENT_KEYS)
  end

  # Linking a record is a create and unlinking or relinking is an update of
  # deleted_at; both are shown only as a change of 'linked':
  #   { 'linked' => [false, true] }
  # Other updates show the changed attributes:
  #   { 'emends' => [true, false] }
  def link_record_changes(version, keys)
    case version.operation
    when 'create'
      { 'linked' => [false, true] }
    when 'update'
      changes = version.changeset.slice(*keys)
      # A nil deleted_at means the record is linked.
      linked = changes.delete('deleted_at')&.map(&:nil?)
      # Changing the timestamp of an already unlinked record is not a link change.
      if linked && linked.first != linked.last
        { 'linked' => linked }
      else
        changes
      end
    else
      {}
    end
  end

  # Pair the type and ID on each side:
  #   [['Strain', 1], ['Genome', 2]]
  def nomenclatural_type_references(nomenclatural_type)
    types = nomenclatural_type.fetch('nomenclatural_type_type', [nil, nil])
    ids = nomenclatural_type.fetch('nomenclatural_type_id', [nil, nil])
    types.zip(ids)
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
