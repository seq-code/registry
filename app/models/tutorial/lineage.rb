module Tutorial::Lineage
  class << self
    def hash
      {
        title: 'Register species lineage',
        prompt: 'New species and parent taxa',
        description: 'If you want to register a novel species from a novel ' \
                     'or existing genus',
        steps: [
          'Name and classification',
          'Lineage',
          'Type',
          'Type details',
          'Description',
          'Etymology',
          'Quality checks',
          'Validation list'
        ]
      }
    end
  end

  ##
  # Lineage Step 00: Create Names
  def lineage_step_00(params, user)
    mandatory = %i[species_name lowest_classified_taxon]
    require_params(params, mandatory) or return false

    # Find classification
    lct = Name.find_by_variants(lowest_classified_taxon)
    unless lct
      errors.add(
        :lowest_classified_taxon,
        "'#{lowest_classified_taxon}' is not a recognized name"
      )
      return false
    end
    if %w[species subspecies].include?(lct.inferred_rank)
      errors.add(
        :lowest_classified_taxon,
        'must be above the rank of species'
      )
      return false
    end

    # Create species name
    name = find_or_register_name(species_name, :species_name, user)
    name or return false
    if name.inferred_rank == 'species'
      name.update(rank: 'species')
    else
      errors.add(:species_name, 'must be the name of a species')
      return false
    end

    Tutorial.transaction do
      names.where.not(id: name.id).update(tutorial_id: nil)
      name.update(tutorial_id: id)
      self.step += 1
      self.data = { lowest_classified_taxon_id: lct.id }.to_json
      save
    end

    true
  end

  ##
  # Lineage Step 01: Lineage
  def lineage_step_01(params, user)
    mandatory = %i[species_name]
    require_params(params, mandatory) or return false
    params[:ranks] ||= ''
  end

  ##
  # Lineage Step 02: Type
  def lineage_step_02(params, user)
    if current_name.type? && params[:next]
      if current_name.type_is_name?
        # Genus and above
        update(step: step + 2)
      else
        # Species and subspecies
        update(step: step + 1)
      end
    else
      @next_action = [:edit_type, current_name, tutorial: self]
    end
  end

  ##
  # Lineage Step 03: Type Details
  def lineage_step_03(params, user)
    if current_name.type_is_genome?
      # Species and subspecies
      if current_name.type_genome.complete? && params[:next]
        update(step: step + 1)
      else
        @notice = 'Please complete the minimum genomic information'
        par = { name: current_name, tutorial: self }
        @next_action = [:edit, current_name.type_genome, par]
      end
    elsif current_name.type_is_name?
      # Genus and above (only if going backwards)
      update(step: step - 1)
    end
  end

  ##
  # Lineage Step 04: Description
  def lineage_step_04(params, user)
    if current_name.description? && params[:next]
      update(step: step + 1)
    else
      @next_action = [:edit, current_name, tutorial: self]
    end
  end

  ##
  # Lineage Step 05: Etymology
  def lineage_step_05(params, user)
    if current_name.etymology? && params[:next]
      update(step: step + 1)
    else
      @next_action = [:edit_etymology, current_name, tutorial: self]
    end
  end

  ##
  # Lineage Step 06: Next Name
  def lineage_step_06(params, user)
    next_name = false
    if current_name.qc_warnings.errors?
      if current_name.can_edit?(user) && current_name.correspondence_by?(user)
        next_name = true
      end
    elsif current_name.parent.id.in? value(:lineage_ids)
      next_name = true
    else
      update(step: step + 1)
    end

    if next_name
      update(
        step: 2,
        data: data_hash.merge(
          current_name_id: current_name.parent.id
        ).to_json
      )
    end
  end

  ##
  # Lineage Step 07: Validation list
  def lineage_step_07(params, user)
    update(ongoing: false)
    @next_action = [:new_register, tutorial: self]
  end

end
