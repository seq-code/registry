module Name::QualityChecks
  ##
  # Test all relevant quality checks and return the QC warnings
  # as a Hash
  def qc_warnings
    return @qc_warnings unless @qc_warnings.nil?

    @qc_warnings = []
    return @qc_warnings if inferred_rank == 'domain'

    unless rank?
      @qc_warnings << {
        type: :missing_rank,
        message: 'The taxon has not been assigned a rank',
        link_text: 'Define rank',
        link_to: [:edit_name_rank_url, self],
        recommendations: %w[7],
        rules: %w[26.4]
      }
    end

    unless identical_base_name.nil?
      @qc_warnings << {
        type: :identical_base_name,
        message: 'Base name already exists with different qualifiers',
        link_text: identical_base_name.abbr_name,
        link_to: [:name_url, identical_base_name],
        link_public: true
      }
    end

    unless description?
      @qc_warnings << {
        type: :missing_description,
        message: 'The name has no registered description',
        link_text: 'Edit description',
        link_to: [:edit_name_url, self],
        rules: %w[9],
        recommendations: %w[9.2]
      }
    end

    if proposed_by.nil?
      @qc_warnings << {
        type: :missing_proposal,
        message: 'The publication proposing this name has not been identified',
        link_text: 'Register publication',
        link_to: [:new_publication_url, { link_name: id }],
        rules: %w[24a],
        can_approve: true
      }
    end

    unless base_name =~ /\A[A-Z][a-z ]+\z/
      $qc_warnings << {
        type: :inconsistent_format,
        message: 'Names should only include Latin characters. ' +
                 'The first epithet must be capitalized, and other ' +
                 'epithets (if any) should be given in lower case',
        rules: %w[8 11 45]
      }
    end

    unless correct_suffix?
      @qc_warnings << {
        type: :incorrect_suffix,
        message: 'The ending of the name is incompatible with the rank of ' +
                 rank,
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: %w[15]
      }
    end

    unless type?
      @qc_warnings << {
        type: :missing_type,
        message: 'The name is missing a type definition',
        link_text: 'Edit type',
        link_to: [:edit_name_type_url, self],
        rules: %w[17 26.3]
      }
    end

    unless consistent_type_rank?
      @qc_warnings << {
        type: :inconsistent_type_rank,
        message: "The nomenclatural type of a #{rank} must " +
                 "be a designated #{expected_type_rank}",
        link_text: 'Edit type',
        link_to: [:edit_name_type_url, self],
        rules: %w[16]
      }
    end

    unless !rank? || top_rank? || !parent.nil?
      @qc_warnings << {
        type: :missing_parent,
        message: 'The taxon has not been assigned to a higher classification',
        link_text: 'Link parent',
        link_to: [:name_link_parent_url, self],
        recommendations: %w[7]
      }
    end

    unless consistent_parent_rank?
      @qc_warnings << {
        type: :inconsistent_parent_rank,
        message: "The parent rank (#{parent.rank}) is inconsistent " +
                 "with the rank of this name (#{rank})",
        link_text: 'Edit parent',
        link_to: [:name_link_parent_url, self],
        rules: %w[7a 7b]
      }
    end

    if rank?
      if rank == 'species' && base_name !~ / /
        @qc_warnings << {
          type: :unary_species_name,
          message: 'Species must be binary names',
          link_text: 'Edit spelling',
          link_to: [:edit_name_url, self],
          rules: %w[8 10]
        }
      end

      if rank == 'subspecies' && base_name !~ /\A[A-Z][a-z]* [a-z]+ subsp\. [a-z]+/
        @qc_warnings << {
          type: :malformed_subspecies_name,
          message: 'Subspecies names should include the species name, ' +
                   'the abbreviation "subsp.", and the subspecies epithet',
          link_text: 'Edit spelling',
          link_to: [:edit_name_url, self],
          rules: %w[13a]
        }
      end

      if !%w[species subspecies].include?(rank) && base_name =~ / /
        @qc_warnings << {
          type: :binary_name_above_species,
          message: 'Names above the rank of species must be single words',
          link_text: 'Edit spelling',
          link_to: [:edit_name_url, self],
          rules: %w[8]
        }
      end

      if rank == 'genus' && Name.rank_regexp.any? { |i| name =~ i }
        @qc_warnings << {
          type: :reserved_suffix,
          message: 'Avoid reserved suffixes for genus names',
          link_text: 'Edit spelling',
          link_to: [:edit_name_url, self],
          recommendations: [10]
        }
      end
    end

    if long_word?
      @qc_warnings << {
        type: :long_name,
        message: 'Consider reducing the length of the name',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        recommendation: %w[9.1]
      }
    end

    if hard_to_pronounce?
      @qc_warnings << {
        type: :hard_to_pronounce,
        message: 'Consider revising the name to make it easier to pronounce',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        recommendation: %w[9.1]
      }
    end

    unless consistent_species_name?
      @qc_warnings << {
        type: :inconsistent_species_name,
        message: 'The first epithet of species names must correspond to the ' +
                 'parent genus',
        link_text: 'Edit parent',
        link_to: [:name_link_parent_url, self],
        rules: %w[8]
      }
    end

    unless consistent_subspecies_name?
      @qc_warnings << {
        type: :inconsistent_subspecies_name,
        message: 'The first two epithets of subspecies names must correspond to the ' +
                 'parent species',
        link_text: 'Edit parent',
        link_to: [:name_link_parent_url, self],
        rules: %w[13a]
      }
    end

    unless consistent_grammar_for_species_or_subspecies?
      @qc_warnings << {
        type: :"inconsistent_grammar_for_#{rank}_name",
        message: "A #{rank} name must be an adjective or a noun",
        link_text: 'Edit etymology',
        link_to: [:edit_name_etymology_url, self],
        rules: rank == 'species' ? %w[12] : %w[13b]
      }
    end

    unless consistent_name_for_subspecies_with_type?
      @qc_warnings << {
        type: :inconsistent_name_for_subspecies_with_type,
        message: 'A subspecies including the type of the species must have the same epithet',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: %w[13c]
      }
    end

    if etymology?
      if etymology(:p1, :grammar) && !etymology(:xx, :grammar)
        @qc_warnings << {
          type: :missing_full_epithet_etymology,
          message: 'The etymology of one or more particles is provided, but ' +
                   'the etymology of the full name or epithet is missing',
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          rules: %w[26.5]
        }
      end
    else
      @qc_warnings << {
        type: :missing_etymology,
        message: 'The etymology of the name has not been provided',
        link_text: 'Edit etymology',
        link_to: [:edit_name_etymology_url, self],
        rules: %w[26.5]
      }
    end

    unless consistent_grammatical_number_and_gender?
      case rank
      when 'genus'
        @qc_warnings << {
          type: :inconsistent_grammatical_number_or_gender,
          message: 'A genus must be given in the singular number',
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          rules: %w[10]
        }
      when 'species', 'subspecies'
        @qc_warnings << {
          type: :inconsitent_grammatical_number_or_gender,
          message: 'A specific epithet formed by an adjective ' +
                   'should agree in number and gender with the parent name',
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          recommendations: rank == 'species' ? %w[12.2] : %w[13b]
          # TODO Revise Rule 13b here, it should probably be a recommendation
        }
      when 'family', 'order'
        @qc_warnings << {
          type: :inconsitent_grammatical_number_or_gender,
          message: "A #{rank} name must be feminine and plural",
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          recommendations: %w[14]
        }
      when 'class', 'phylum'
        @qc_warnings << {
          type: :inconsitent_grammatical_number_or_gender,
          message: "A #{rank} name must be neuter and plural",
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          recommendations: %w[14]
        }
      end
    end

    @qc_warnings
  end

  def identical_base_name
    if candidatus?
      @identical_base_name ||= Name.where(name: base_name).first
    else
      @identical_base_name ||= Name.where(name: "Candidatus #{name}").first
    end
  end

  def correct_suffix?
    regexp = self.class.rank_regexp[rank.to_s.to_sym]
    return true if regexp.nil? # domain, genus, species, subspecies, undefined

    name =~ regexp
  end

  def consistent_parent_rank?
    return true if !rank? || parent.nil? || !parent.rank?

    self.class.ranks.index(rank) == self.class.ranks.index(parent.rank) + 1
  end

  def consistent_type_rank?
    return true if !rank? || %w[species subspecies].include?(rank) || !type?

    type_name.rank == expected_type_rank
  end

  def consistent_species_name?
    return true if !rank? || rank != 'species' || parent.nil? || !parent.rank?

    base_name.sub(/ .*/, '') == parent.base_name
  end

  def consistent_subspecies_name?
    return true if !rank? || rank != 'subspecies' || parent.nil? || !parent.rank?

    base_name.sub(/\A(\S+\s+\S+)\s.*/, '\\1') == parent.base_name
  end

  def consistent_grammatical_number_and_gender?
    return true if !rank? || !grammar

    case rank
    when 'genus'
      !plural?
    when 'species', 'subspecies'
      return true unless parent&.grammar # If it cannot be checked
      return true unless adjective? # Only adjectives are checked

      agree = %i[plural? masculine? feminine? neuter?]
      agree.all? { |x| parent.send(x) == send(x) }
    when 'family', 'order'
      return false unless feminine?
      return false unless plural?
      true
    when 'class', 'phylum'
      return false unless neuter?
      return false unless plural?
      true
    else
      true
    end
  end

  def consistent_grammar_for_species_or_subspecies?
    return true if !rank? || !%w[species subspecies].include?(rank) || !grammar

    if adjective?
      true # Rule 12.1 for species, 13b for subspecies
    elsif noun?
      true # Rule 12.2 / 12.3 for species, 13b for subspecies
    else
      false
    end
  end

  def consistent_name_for_subspecies_with_type?
    return true if !rank? || rank != 'subspecies' || !type? || !parent&.type?
    return true if type_text != parent.type_text
    return true if last_epithet == parent.last_epithet

    false
  end
end
