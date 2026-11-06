class Name::PublicHistory
  # Only these recorded attributes of each record type appear in the public
  # history of a name.
  ATTRIBUTES = {
    'Name' => %w[
      name rank syllabication status priority_date authority
      nomenclatural_status taxonomic_status proposal_kind corrigendum_from corrigendum_kind
      nomenclatural_type_type nomenclatural_type_id
      proposed_in_id corrigendum_in_id assigned_in_id
      parent_id correct_name_id basonym_id redirect_id genome_strain
      ncbi_taxonomy lpsn_url gtdb_accession algaebase_species algaebase_taxonomy
      wikidata_item wikispecies_entry
    ] + Name::ETYMOLOGY_COLUMNS,
    'PublicationName' => %w[publication_id emends not_valid_proposal],
    'Placement' => %w[parent_id publication_id incertae_sedis preferred],
    'ActionText::RichText' => %w[body]
  }.freeze
  # Only these rich texts of the name appear in the public history.
  RICH_TEXT_NAMES = %w[description etymology_text].freeze

  def initialize(name)
    @name = name
  end

  # Load all histories and filter displayable changes in Ruby before pagination.
  def versions(page:)
    Version.where(owner: @name)
           .includes(:user)
           .order(created_at: :desc, id: :desc)
           .select { |version| changes_for(version).any? }
           .paginate(page: page, per_page: 25)
  end

  # The public attributes a version changed, e.g.
  # { 'authority' => [nil, 'Castellani and Chalmers 1919'] }.
  # Always versioned attributes stay even when unchanged, as context.
  def changes_for(version)
    if version.record_type == 'ActionText::RichText'
      return {} unless RICH_TEXT_NAMES.include?(version.changeset['name'].compact.first)
    end

    model = version.record_type.constantize
    changes = version.changeset.slice(*ATTRIBUTES.fetch(version.record_type))
    group_polymorphic(changes, model)
    group_etymology(changes, version.changeset['name']) if model == Name
    context = model.always_versioned_attributes
    changes.reject do |attribute, (before, after)|
      before == after && (before.nil? || !context.include?(attribute))
    end
  end

  private

  # A polymorphic reference is its type and ID together:
  #   { 'nomenclatural_type' => [['Strain', 1], ['Genome', 2]] }
  def group_polymorphic(changes, model)
    model.reflect_on_all_associations(:belongs_to).select(&:polymorphic?).each do |association|
      types, ids = changes.extract!(association.foreign_type, association.foreign_key)
                          .values_at(association.foreign_type, association.foreign_key)
      next unless types || ids

      changes[association.name.to_s] = (types || [nil, nil]).zip(ids || [nil, nil])
    end
  end

  # Etymology is read as a whole, so each side becomes all of its recorded
  # parts and the name, from whose last word full_etymology derives :xx:
  #   { 'etymology' => [{ 'name' => 'Escherichia coli', 'etymology_xx_lang' => 'N.L.', ... }, {...}] }
  def group_etymology(changes, names)
    etymology = changes.extract!(*Name::ETYMOLOGY_COLUMNS).reject { |_, values| values.compact.empty? }
    return if etymology.empty?

    changes['etymology'] = names.each_index.map do |side|
      etymology.transform_values { |values| values[side] }.merge('name' => names[side])
    end
  end
end
