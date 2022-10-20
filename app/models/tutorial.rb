class Tutorial < ApplicationRecord
  belongs_to(:user)
  has_many(:names, dependent: :nullify)

  %i[
    species_name genus_name family_name order_name class_name phylum_name
    lowest_classified_taxon lineage_ids ranks name_description
  ].each do |i|
    attr(i)
    attr_writer(i)
  end

  class << self
    def tutorials_hash
      {
        lineage: {
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
        },
        batch: {
          title: 'Batch upload of new names',
          prompt: 'New names from a single spreadsheet',
          description: 'If you want to upload up to 100 names described in a ' \
                       'spreadsheet template',
          steps: []
        },
        subspecies: {
          title: 'Register subspecies',
          prompt: 'New subspecies from a previously described species',
          description: 'If you want to register a new subspecies from a ' \
                       'species that is already validly published under the ' \
                       'SeqCode or under the ICNP rules, or currently under ' \
                       'revision in the SeqCode Registry',
          steps: []
        },
        parent: {
          title: 'Register higher taxa',
          prompt: 'New taxon above the rank of species',
          description: 'If you want to register the name of a genus, family, ' \
                       'order, class, or phylum, for which the type species ' \
                       '(or genus) is already validly published under the ' \
                       'SeqCode or under the ICNP rules, or currently under ' \
                       'revision in the SeqCode Registry',
          steps: []
        },
        neotype: {
          title: 'Register new type',
          prompt: 'New type for an existing taxon',
          description: 'If you want to register a different genome as the ' \
                       'material of an existing species or subspecies, or ' \
                       'want to register a different genus as the type name ' \
                       'of a taxon above the rank of genus',
          steps: []
        }
      }
    end
  end

  def symbol
    pipeline.to_sym
  end

  def tutorial_hash
    self.class.tutorials_hash[symbol]
  end

  %i[title prompt description steps].each do |i|
    define_method(i) { tutorial_hash[i] }
  end

  def step_name
    steps[step]
  end

  def next_step_symbol
    :"#{symbol}_step_#{'%02i' % step}"
  end

  def next_step(params, user)
    send(next_step_symbol, params, user)
  end

  def lowest_classified_taxon_obj
    @lowest_classified_taxon_obj ||=
      Name.where(id: value(:lowest_classified_taxon_id)).first
  end

  def lowest_new_name
    Name.ranks.reverse.each do |i|
      n = names.find { |j| j.rank == i }
      return n if n
    end
  end

  def current_name
    @current_name ||= Name.where(id: value(:current_name_id)).first
  end
  
  def next_action
    @next_action ||= self
  end

  def notice
    @notice ||= nil
  end

  def data_hash
    @data_hash ||= JSON.parse(data || '{}')
  end

  def value(key)
    data_hash[key.to_s]
  end

  def find_or_register_name(name, field, user)
    base = name.gsub(/^Candidatus /, '')
    n = Name.find_by_variants(base)
    if n
      unless n.can_edit?(user) || n.can_claim?(user)
        errors.add(
          field,
          'already exists, but you do not have editing or claiming privileges'
        )
        return
      end

      # Claim and correct
      n.status = 5 if n.status == 0
      n.created_by = user
      n.created_at = Time.now
      n.name.gsub!(/^Candidatus /, '')
    end
    n ||= Name.new(name: name, status: 5, created_by: user)

    unless n.save
      errors.add(
        field,
        'produced an internal error: ' +
          n.errors.map { |i| "#{i.attribute} #{i.message}" }.join(', ')
      )
      return nil
    end

    n
  end

  def add_to_register(register, user)
    Tutorial.transaction do
      names.each do |name|
        name.add_to_register(register, user)
      end
    end
  end

  private

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

      # Register names
      ranks = params[:ranks].split(' ') + ['species']
      require_params(params, ranks.map { |i| :"#{i}_name" }) or return false

      # Create names
      lineage_ids = []
      parent = lowest_classified_taxon_obj
      types  = {}
      ranks.each_with_index do |rank, k|
        field = :"#{rank}_name"
        name = find_or_register_name(params[field], field, user) or return false
        case rank.to_s
          when 'species'; types[:species] = name.id
          when 'genus';   types[:genus]   = name.id
        end
        name.update(rank: rank, tutorial_id: id, parent: parent)
        lineage_ids << name.id
        parent = name
      end

      # Set type material for genus and above
      lineage_ids.each do |name_id|
        name = Name.find(name_id)
        case name.rank
        when 'species'
          # Do nothing
        when 'genus'
          name.update(type_material: :name, type_accession: types[:species])
        else
          name.update(type_material: :name, type_accession: types[:genus])
        end
      end

      self.step += 1
      self.data = data_hash.merge(
        lineage_ids: lineage_ids.reverse,
        current_name_id: lineage_ids.last
      ).to_json
      save
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

    def require_params(params, keys)
      o = true
      keys.each do |i|
        if params[i].blank?
          errors.add(i, message: 'cannot be blank')
          o = false
        else
          send("#{i}=", params[i])
        end
      end
      o
    end
end

