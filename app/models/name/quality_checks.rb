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
        message: 'Name already exists with different qualifiers',
        link_text: identical_base_name.abbr_name,
        link_to: [:name_url, identical_base_name],
        link_public: true,
        rules: %w[9b],
        recommendations: %w[9.2]
      }
    end

    unless external_homonyms.empty?
      @qc_warnings << {
        type: :identical_external_name,
        message:
          "Name is already in use: #{external_homonyms.to_sentence}".html_safe,
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: %w[9b],
        recommendations: %w[9.2]
      }
    end

    unless description?
      @qc_warnings << {
        type: :missing_description,
        message: 'The name has no registered description',
        link_text: 'Edit description',
        link_to: [:edit_name_url, self]
      }
    end

    if proposed_by.nil?
      @qc_warnings << {
        type: :missing_effective_publication,
        message: 'The publication proposing this name has not been identified',
        link_text: 'Register publication',
        link_to: [:new_publication_url, { link_name: id }],
        rules: %w[24a],
        can_approve: true
      }
    elsif proposed_by.prepub?
      @qc_warnings << {
        type: :invalid_effective_publication,
        message: 'The publication proposing this name is a preprint or some ' \
                 'other type of publication not accepted',
        link_text: 'Register another publication',
        link_to: [:new_publication_url, { link_name: id }],
        rules: %w[24c]
      }
    end

    unless base_name =~ /\A[A-Z][a-z ]+( subsp\. )?[a-z ]+\z/
      @qc_warnings << {
        type: :inconsistent_format,
        message: 'Names should only include Latin characters. ' +
                 'The first word must be capitalized, and other ' +
                 'epithets (if any) should be given in lower case',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: %w[8 45] + (
          case inferred_rank
          when 'genus'; %w[10]
          when 'species'; %w[11]
          when 'subspecies'; %w[13a 13b]
          else %w[14]
          end
        )
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

    if type?
      if %w[species subspecies].include?(inferred_rank) &&
           !%w[nuccore assembly].include?(type_material)
        @qc_warnings << {
          type: :unrecognized_type_material,
          message: 'A sequence used as type material must be available ' +
                   'in the INSDC databases',
          link_text: 'Edit type',
          link_to: [:edit_name_type_url, self],
          rules: %w[18a]
        }
      end
    else
      @qc_warnings << {
        type: :missing_type,
        message: 'The name is missing a type definition',
        link_text: 'Edit type',
        link_to: [:edit_name_type_url, self],
        rules: %w[16 17 26.3] + (
          %w[subspecies species].include?(inferred_rank) ? %w[18a] :
          %w[genus].include?(inferred_rank) ? %w[21a] : []
        )
      }
    end

    if type_is_name? && !type_name.validated?
      @qc_warnings << {
        type: :non_valid_name_as_type,
        message: 'Only a valid name can be used as nomenclatural type',
        link_text: 'Edit type',
        link_to: [:edit_name_type_url, self],
        rules: %w[20],
        can_approve: true
      }
    end

    unless consistent_type_rank?
      @qc_warnings << {
        type: :inconsistent_type_rank,
        message: "The nomenclatural type of a #{inferred_rank} must " +
                 "be a designated #{expected_type_rank}",
        link_text: 'Edit type',
        link_to: [:edit_name_type_url, self],
        rules: %w[16] + (inferred_rank == 'genus' ? %w[21a] : [])
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
                 "with the rank of this name (#{inferred_rank})",
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
          rules: %w[8 11]
        }
      end

      if rank == 'subspecies' && base_name !~ /\A[A-Z][a-z]* [a-z]+ subsp\. [a-z]+\z/
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
          rules: %w[8 10]
        }
      end

      if rank == 'genus'
        if self.class.rank_regexps.any? { |_, i| name =~ i }
          @qc_warnings << {
            type: :reserved_suffix,
            message: 'Avoid reserved suffixes for genus names',
            link_text: 'Edit spelling',
            link_to: [:edit_name_url, self],
            recommendations: %w[10]
          }
        end

        if etymology? && !latin?
          @qc_warnings << {
            type: :inconsistent_language_for_genus,
            message: 'A genus name must be treated as Latin (L. or N.L.)',
            link_text: 'Edit etymology',
            link_to: [:edit_name_etymology_url, self],
            rules: %w[10]
          }
        end
      end
    end

    unless consistent_with_type_genus?
      @qc_warnings << {
        type: :inconsistent_with_type_genus,
        message: "The name should be formed by adding the suffix " +
                 "-#{rank_suffix} to the stem of the type genus",
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rules: %w[15]
      }
    end

    unless consistent_etymology_with_type_genus?
      @qc_warnings << {
        type: :inconsistent_with_type_genus,
        message: "The etymology should be formed by the stem of the type " +
                 "genus and the suffix -#{rank_suffix}",
        link_text: 'Autofill etymology',
        link_to: [:autofill_etymology_url, self, method: :post],
        rules: %w[15]
      }
    end

    if long_word?
      @qc_warnings << {
        type: :long_name,
        message: 'Consider reducing the length of the name',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        recommendations: %w[9.1]
      }
    end

    if hard_to_pronounce?
      @qc_warnings << {
        type: :difficult_to_pronounce,
        message: 'Consider revising the name to make it easier to pronounce',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        recommendations: %w[9.1]
      }
    end

    unless consistent_species_name?
      @qc_warnings << {
        type: :inconsistent_species_name,
        message: 'The first word of species names must correspond to the ' +
                 'parent genus',
        link_text: 'Edit parent',
        link_to: [:name_link_parent_url, self],
        rules: %w[8 11]
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
        message: "A #{inferred_rank} name must be an adjective or a noun",
        link_text: 'Edit etymology',
        link_to: [:edit_name_etymology_url, self],
        rules: (rank == 'subspecies' ? %w[13b] : []) + %w[12]
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

    unless consistent_genus_gender?
      if feminine? || masculine? || neuter?
        @qc_warnings << {
          type: :missing_grammatical_gender,
          message: 'Authors must give the gender of any proposed genus name',
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          rules: %w[49.1 49.3]
        }
      else
        @qc_warnings << {
          type: :inconsistent_grammatical_gender,
          message: 'A genus name formed by two or more Latin words should take ' +
                   'gender of the last component of the word',
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          rules: %w[49.2]
        }
      end
    end

    unless consistent_grammatical_number_and_gender?
      case inferred_rank
      when 'genus'
        @qc_warnings << {
          type: :inconsistent_grammatical_number,
          message: 'A genus must be a noun or and adjective used as a noun, ' +
                   'given in the singular number',
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          rules: %w[10]
        }
      when 'species', 'subspecies'
        @qc_warnings << {
          type: :inconsistent_grammatical_number_or_gender,
          message: 'A specific epithet formed by an adjective ' +
                   'should agree in number and gender with the parent name' +
                   (inferred_rank == 'subspecies' ? ' (see Rule 13b)' : ''),
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          recommendations: %w[12.2]
        }
      when 'family', 'order'
        @qc_warnings << {
          type: :inconsistent_grammatical_number_or_gender,
          message: "A name in the rank of #{inferred_rank} must be " +
                   "feminine and plural",
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          recommendations: %w[14]
        }
      when 'class', 'phylum'
        @qc_warnings << {
          type: :inconsistent_grammatical_number_or_gender,
          message: "A name in the rank of #{inferred_rank} must be " +
                   "neuter and plural",
          link_text: 'Edit etymology',
          link_to: [:edit_name_etymology_url, self],
          recommendations: %w[14]
        }
      end
    end

    if corrigendum_from &&
         corrigendum_from.sub(/^Candidatus /, '')[0] != base_name[0]
      @qc_warnings << {
        type: :corrigendum_affecting_initials,
        message: 'A corrigendum should be issued with reserve when affecting ' \
                 'the first letter of a name',
        link_text: 'Edit spelling',
        link_to: [:edit_name_url, self],
        rule_notes: %w[47]
      }
    end

    @qc_warnings.map do |warning|
      is_error = warning[:rules] && (!warning[:can_approve] || notified?)
      warning[:fail] = is_error ? :error : :warn
      warning
    end
  end

  def identical_base_name
    if candidatus?
      @identical_base_name ||= Name.where(name: base_name).first
    else
      @identical_base_name ||= Name.where(name: "Candidatus #{name}").first
    end
  end

  def correct_suffix?
    regexp = self.class.rank_regexps[rank.to_s.to_sym]
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

  def consistent_genus_gender?
    return true unless rank? && grammar && rank == 'genus'

    # Rule 49.1
    return false unless feminine? || masculine? || neuter?

    # Rules 49.1 and 49.3
    return true if [:p1, nil].include?(last_component)

    # Rule 49.1 and 49.3
    return true unless self.class.etymology_particles.map { |i| latin?(i) }.compact.all?

    # Rule 49.2
    %i[feminine? masculine? neuter?].all? do |i|
      self.send(i) == self.send(i, last_component)
    end
  end

  def consistent_grammatical_number_and_gender?
    return true if !rank? || !grammar

    case rank
    when 'genus'
      return false if plural?
      adjective? || noun?
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

  def consistent_with_type_genus?
    return true unless rank? && type_is_name?
    return true unless rank_suffix

    root = base_name.sub(/#{rank_suffix}$/, '')
    !!(type_name.base_name =~ /^#{root}/)
  end

  def consistent_etymology_with_type_genus?
    return true unless rank? && type_is_name? && type_name.rank == 'genus'

    first_particle = etymology(:p1, :particle)
    first_particle ? type_name.base_name == first_particle : true
  end
end
