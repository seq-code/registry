module Tutorial::Batch
  class << self
    def hash
      {
        title: 'Batch upload of new names',
        prompt: 'New names from a single spreadsheet',
        description: 'If you want to upload up to 100 names described in a ' \
                     'spreadsheet template',
        steps: [
          'Upload spreadsheet',
          'Review parsed data',
          'Validation list'
        ]
      }
    end

    def name_keys_base
      %i[
        name rank description syllabication parent type_material type_accession
      ]
    end

    def genome_keys
      %i[
        database accession source_database source_accession kind
        seq_depth gc_content completeness contamination
        most_complete_16s number_of_16s most_complete_23s number_of_23s
        number_of_trnas submitter_comments
      ]
    end
  end

  ##
  # Take the JSON data and sanitize it as params for name update or creation
  def param_names
    @param_names ||=
      (value(:names) || []).map do |i|
        i.dup.tap do |j|
          # Sanitize
          j.each do |k, v|
            next if k == 'description'
            if v.is_a? String
              j[k] = ActionController::Base.helpers.strip_tags(v).strip
            end
          end

          # Deal with foreign keys
          if j['parent'] &&
               j['parent'] =~ /^incertae sedis( \((Archaea|Bacteria)\))?/
            j['incertae_sedis'] = j['parent']
            j['parent'] = nil
          end
          j['parent'] &&= Name.new(name: j['parent'])
          if j['type_material'] == 'name' && j['type_accession']
            j['type_name'] = Name.new(name: j['type_accession'])
          end

          # Additional modifications
          j.delete('etymology_xx_particle')
          j['tutorial_id'] = id
        end
      end
  end

  ##
  # Take the JSON data and create temporary representations as +Name+ objects
  def ephemeral_names
    @ephemeral_names ||=
      param_names.map do |i|
        Name.new(i)
      rescue => e
        $stderr.puts e
        nil
      end
  end

  def name_exists?(name)
    return false unless name
    return true if ephemeral_names.map(&:name).include? name
    !Name.find_by_variants(name).nil?
  end

  def genome_exists?(name)
    genome = [name.type_material, name.type_accession]
    ephemeral_genomes.map { |g| [g.database, g.accession] }.include? genome
  end

  def genome_is_unique?(name)
    g = Genome.find_by(
      database: name.type_material, accession: name.type_accession
    )
    return true if g.nil? || g.names.empty?

    g.names.map(&:name).include?(name.name)
  end

  def check_ephemeral_names(user)
    @check_ephemeral_names ||= :pending
    return ephemeral_names if @check_names == :done

    name_names = ephemeral_names.map(&:name)
    ephemeral_names.each do |name|
      # Is the information complete?
      Tutorial::Batch.name_keys_base.each do |i|
        unless name.send(i).present?
          name.errors.add(i, :missing, 'is missing')
        end
      end

      # Is the etymology present?
      unless name.etymology?
        name.errors.add(:etymology_xx_description, :missing, 'is missing')
      end

      # Is the name already registered?
      var = Name.find_by_variants(name.name)
      if var && !var.can_claim?(user)
        name.errors.add(
          :name, :exist,
          message: 'already exists and cannot be claimed by user'
        )
      end

      # Is the parent already registered?
      if name.parent && !name_exists?(name.parent.name)
        name.errors.add(
          :parent, :does_not_exist,
          message: 'does not exist and is not proposed in this list'
        )
      end

      # Is the type name already registered?
      if name.type_material == 'name'
        if !name_exists?(name.type_name.try(:name))
          name.errors.add(
            :type_accession, :does_not_exist,
            message: 'is not an existing name and is not proposed in this list'
          )
        end
      else
       if !genome_exists?(name)
         name.errors.add(
           :type_accession, :does_not_exist,
           message: 'is not an existing genome and is not described here'
         )
       elsif !genome_is_unique?(name)
         name.errors.add(
           :type_accession, :is_a_type,
           message: 'is already the type genome for a different name'
         )
       end
      end
    end
    @check_names = :done
  end

  def check_ephemeral_genomes(user)
    @check_ephemeral_genomes ||= :pending
    return ephemeral_genomes if @check_ephemeral_genomes == :done

    ephemeral_genomes.each do |genome|
      # Check minimum required information
      Genome.required.each do |i|
        i = i.to_s.gsub(/_any$/, '')
        unless genome.send(i)
          genome.errors.add(i, :missing, message: 'is missing')
        end
      end

      # Check if user can edit
      g = Genome.where(
        database: genome.database, accession: genome.accession
      ).first
      if g && !g.can_edit?(user)
        genome.errors.add(
          :accession, :cannot_edit,
          message: 'is already registered and user cannot edit it'
        )
      end
    end
    @check_ephemeral_genomes = :done
  end

  ##
  # Take the JSON data on and create param hashes for genome creation or update
  def param_genomes
    @param_genomes ||=
      (value(:genomes) || []).map do |i|
        i.dup.tap do |j|
          # Sanitize
          j.each do |k, v|
            next if k == 'comments'
            if v.is_a? String
              j[k] = ActionController::Base.helpers.strip_tags(v).strip
            end
          end
        end
      end
  end

  ##
  # Take the JSON data and create temporary representations as +Genome+ objects
  def ephemeral_genomes
    @ephemeral_genomes ||=
      param_genomes.map do |i|
        Genome.new(i)
      rescue => e
        $stderr.puts e
        nil
      end
  end

  ##
  # Parse the proposed names sheet
  def parse_proposed_names(sheet)
    names = []
    name_keys = Tutorial::Batch.name_keys_base
    Name.etymology_particles.each do |i|
      Name.etymology_fields.each { |j| name_keys << :"etymology_#{i}_#{j}" }
    end
    sheet.each do |r|
      name = {}
      name_keys.each { |k| name[k] = r.shift }
      names << name
      break if names.size > 103
    end
    names.shift(3) # Discard headers
    names
  end

  ##
  # Parse the proposed genomes sheet
  def parse_proposed_genomes(sheet)
    genomes = []
    sheet.each do |r|
      genome = {}
      Tutorial::Batch.genome_keys.each { |k| genome[k] = r.shift }
      genomes << genome
      break if genomes.size > 102
    end
    genomes.shift(2) # Discard headers
    genomes
  end

  ##
  # Batch Step 00: Upload spreadsheet
  def batch_step_00(params, user)
    require_params(params, [:file]) or return false

    xlsx = Roo::Spreadsheet.open(params[:file].path)

    # Parse Proposed Names sheet
    names_sheet = xlsx.sheet('Proposed Names')
    names = parse_proposed_names(names_sheet)

    # Parse Type Genomes sheet
    genomes_sheet = xlsx.sheet('Type Genomes')
    genomes = parse_proposed_genomes(genomes_sheet)

    # Save in tutorial
    update!(step: step + 1, data: { names: names, genomes: genomes }.to_json)
  end

  ##
  # Batch Step 01: Create or claim names
  def batch_step_01(params, user)
    Tutorial.transaction do
      # Save genomes
      ephemeral_genomes.each_with_index do |genome, idx|
        g = Genome.where(
          database: genome.database, accession: genome.accession
        ).first
        if g
          g.update!(param_genomes[idx])
        else
          genome.save
        end
      end

      # Save or claim names
      param_names.each do |par_ori|
        # Remove foreign keys in first pass
        par = par_ori.dup
        par['parent'] = nil
        par['type_accession'] = nil if par['type_material'] == 'name'

        # Claim/update or create
        name = Name.find_by_variants(par['name'])
        if name
          name.claim(user)
          name.update!(par)
        else
          name = Name.create!(par)
        end
      end

      # Link foreign keys
      default_pars = {status: 0, created_by: user}
      param_names.each do |par|
        new_par = {}

        # Parents
        if par['parent']
          new_par[:parent] = Name.find_by_variants(par['parent'].name)
          unless new_par[:parent]
            name = Name.new(default_pars.merge(name: par['parent'].name))
            name.save!
            new_par[:parent_id] = name.id
          end
        end

        # Type names
        if par['type_material'] == 'name' && par['type_material']
          new_par[:type_accession] =
            Name.find_by_variants(par['type_accession']).try(:id)
          unless new_par[:type_accession]
            name = Name.new(default_pars.merge(name: par['type_material']))
            name.save!
            new_par[:type_accession] = name.id
          end
        end

        Name.find_by_variants(par['name']).update!(new_par)
      end

      # If all is good, go to next step
      update!(step: step + 1)
    end # Tutorial.transaction
  end

  ##
  # Batch Step 02: Validation list
  def batch_step_02(params, user)
    update!(ongoing: false)
    @next_action = [:new_register, tutorial: self]
  end

end
