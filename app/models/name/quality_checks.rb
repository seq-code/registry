module Name::QualityChecks
  ##
  # Model QC Warnings as objects
  class QcWarning

    mattr_accessor :defaults

    # Attributes supported for warnings
    @@attributes = %i[
      message link_text link_to rules recommendations can_endorse
      link_public rule_notes checklist
    ]

    # Preformed links to common targets
    @@link_to_edit_spelling = {
      link_text: 'Edit spelling',
      link_to: lambda { |w| [:edit, w.name] }
    }
    @@link_to_edit_type = {
      link_text: 'Edit type',
      link_to: lambda { |w| [:edit_type, w.name] }
    }
    @@link_to_edit_genome = {
      link_text: 'Edit genome',
      link_to: lambda { |w| [:edit, w.name.type_genome, name: w.name.id] }
    }
    @@link_to_edit_parent = {
      link_text: 'Edit parent',
      link_to: lambda { |w| [:edit_parent, w.name] }
    }
    @@link_to_edit_etymology = {
      link_text: 'Edit etymology',
      link_to: lambda { |w| [:edit_etymology, w.name] }
    }

    # Default values for all evaluated warnings
    @@defaults = {
      # Not explicitly stated in the SeqCode
      missing_description: {
        message: 'The name has no registered description',
        link_text: 'Edit description',
        link_to: lambda { |w| [:edit, w.name] }
      },
      candidatus_modifier: {
        message: 'The name has a Candidatus modifier that should be removed'
      }.merge(@@link_to_edit_spelling),
      inconsistent_syllabification: {
        message: 'The syllabification does not correspond to the proposed ' \
                 'spelling'
      }.merge(@@link_to_edit_etymology),
      too_many_amino_acids: {
        message: 'The genome is reported to encode tRNAs for too many ' \
                 'amino acids'
      }.merge(@@link_to_edit_genome),
      discrepant_gc_content: {
        message: 'The reported G+C content has over 10% difference with ' \
                 'the automated estimate'
      }.merge(@@link_to_edit_genome),
      discrepant_completeness: {
        message: 'The reported completeness has over 10% difference with ' \
                 'the automated estimate'
      }.merge(@@link_to_edit_genome),
      discrepant_contamination: {
        message: 'The reported contamination has over 10% difference with ' \
                 'the automated estimate'
      }.merge(@@link_to_edit_genome),
      discrepant_most_complete_16s: {
        message: 'The reported fraction of 16S fragments has over 10% ' \
                 'difference with the automated estimate'
      }.merge(@@link_to_edit_genome),
      discrepant_number_of_16s: {
        message: 'The reported number of 16S fragments has over 10% ' \
                 'difference with the automated estimate'
      }.merge(@@link_to_edit_genome),
      discrepant_most_complete_23s: {
        message: 'The reported fraction of 23S fragments has over 10% ' \
                 'difference with the automated estimate'
      }.merge(@@link_to_edit_genome),
      discrepant_number_of_23s: {
        message: 'The reported number of 23S fragments has over 10% ' \
                 'difference with the automated estimate'
      }.merge(@@link_to_edit_genome),
      discrepant_number_of_trnas: {
        message: 'The reported number amino acids with tRNA elements has ' \
                 'over 10% difference with the automated estimate'
      }.merge(@@link_to_edit_genome),

      # Section 1. General
      # - Rules 1-6 deal with the structure of the SeqCode and the SeqCode
      #   Committee, and do not regulate names

      # Section 2. Ranks of Taxa
      # - Rules 7a and 7b
      inconsistent_parent_rank: {
        message: lambda { |w|
          "The parent rank (#{w.name.parent.rank}) is inconsistent " +
            "with the rank of this name (#{w.name.inferred_rank})"
        },
        rules: %w[7a 7b]
      }.merge(@@link_to_edit_parent),
      # - Rules 7c and 7d are implied by the structure of the SeqCode Registry
      # - Recommendation 7
      missing_rank: {
        message: 'The taxon has not been assigned a rank',
        link_text: 'Define rank',
        link_to: lambda { |w| [:edit_rank, w.name] },
        recommendations: %w[7],
        rules: %w[26.4]
      },
      missing_parent: {
        message: 'The taxon has not been assigned to a higher classification',
        link_text: 'Link parent',
        link_to: lambda { |w| [:edit_parent, w.name] },
        recommendations: %w[7]
      },

      # Section 3. Naming of Taxa
      # - Rule 8
      inconsistent_language: {
        message: 'A name must be treated as Latin (L. or N.L.)',
        rules: %w[8]
      }.merge(@@link_to_edit_etymology),
      inconsistent_format: {
        message: 'Names should only include Latin characters. ' \
                 'The first word must be capitalized, and other ' \
                 'epithets (if any) should be given in lower case',
        rules: lambda { |w|
          %w[8 46] + (
            case w.name.inferred_rank
            when 'genus'; %w[10]
            when 'species'; %w[11]
            when 'subspecies'; %w[13a 13b]
            else %w[14]
            end
          )
        }
      }.merge(@@link_to_edit_spelling),
      binary_name_above_species: {
        message: 'Names above the rank of species must be single words',
        rules: %w[8 10]
      }.merge(@@link_to_edit_spelling),
      inconsistent_species_name: {
        message: 'The first word of species names must correspond to the ' \
                 'parent genus',
        rules: %w[8 11]
      }.merge(@@link_to_edit_parent),
      unary_species_name: {
        message: 'Species must be binary names',
        rules: %w[8 11]
      }.merge(@@link_to_edit_spelling),
      # - Rule 9a automatically enforced by the Registry
      # - Rule 9b
      identical_base_name: {
        message: 'Name already exists with different qualifiers',
        rules: %w[9b],
        recommendations: %w[9.2],
        link_text: lambda { |w| w.name.identical_base_name.abbr_name },
        link_to: lambda { |w| w.name.identical_base_name },
        link_public: true
      },
      identical_external_name: {
        message: lambda { |w|
          homonyms = w.name.external_homonyms
          "Name is already in use: #{homonyms.to_sentence}".html_safe
        },
        rules: %w[9b],
        recommendations: %w[9.2]
      }.merge(@@link_to_edit_spelling),
      long_name: {
        message: 'Consider reducing the length of the name',
        recommendations: %w[9.1]
      }.merge(@@link_to_edit_spelling),
      difficult_to_pronounce: {
        message: 'Consider revising the name to make it easier to pronounce',
        recommendations: %w[9.1]
      }.merge(@@link_to_edit_spelling),
      # - Recommendation 9.1 covered in § Rule 9b
      # - Recommendation 9.2 [TODO: issue #6]:
      #   Names should differ by at least three characters from existing names
      #   of genera or species within the same genus.
      # - Recommendation 9.3 [Checklist-N]
      latin_should_be_preferred: {
        checklist: :nomenclature,
        message: 'Languages other than Latin should be avoided when possible',
        recommendations: %w[9.3]
      }.merge(@@link_to_edit_etymology),
      # - Recommendation 9.4 [Checklist-N]
      inapt_personal_name: {
        checklist: :nomenclature,
        message: 'Personal name dedication should be appropriately formed',
        recommendations: %w[9.4]
      }.merge(@@link_to_edit_etymology),
      # - Recommendation 9.5 [Checklist-N]
      personal_genus_must_be_feminine: {
        checklist: :nomenclature,
        message: 'Personal genus names should be feminine',
        recommendations: %w[9.4]
      }.merge(@@link_to_edit_etymology),
      # - Recommendation 9.6 [Checklist-N]
      contentious_name: {
        checklist: :nomenclature,
        message: 'Names should not be contentious or abusive',
        recommendations: %w[9.6]
      }.merge(@@link_to_edit_etymology),
      # - Recommendation 9.7 [Checklist-N]
      lacking_mnemonic_cues: {
        checklist: :nomenclature,
        message: 'Names with mnemonic cues are preferred',
        recommendations: %w[9.7]
      }.merge(@@link_to_edit_etymology),
      # - Rule 10
      inconsistent_genus_grammatical_number_or_gender: {
        message: 'A genus must be a noun or an adjective used as a noun, ' \
                 'given in the singular number',
        rules: %w[10]
      }.merge(@@link_to_edit_etymology),
      # - Recommendation 10
      reserved_suffix: {
        message: 'Avoid reserved suffixes for genus names',
        recommendations: %w[10.1]
      }.merge(@@link_to_edit_spelling),
      # - Rule 11 covered in § Rule 8
      # - Rule 12
      inconsistent_grammar_for_species_name: {
        message: 'A species name must be an adjective or a noun',
        rules: %w[12]
      }.merge(@@link_to_edit_etymology),
      inconsistent_grammar_for_subspecies_name: {
        message: 'A subspecies name must be an adjective or a noun',
        rules: %w[12 13b]
      }.merge(@@link_to_edit_etymology),
      # - Rule 12 [Checklist-N]
      inconsistent_epithet_relationship_to_genus: {
        checklist: :nomenclature,
        message: 'The epithet must relate grammatically to the genus name',
        rules: lambda { |w|
          w.name.inferred_rank == 'subspecies' ? %w[12 13b] : %w[12]
        }
      }.merge(@@link_to_edit_etymology),
      # - Recommendation 12.1 [Checklist-N]
      unspecific_epithet: {
        checklist: :nomenclature,
        message: 'Species epithet should reflect distinct features ' \
                 'in the genus',
        recommendations: %w[12.1]
      }.merge(@@link_to_edit_spelling),
      # - Recommendation 12.2
      inconsistent_species_grammatical_number_or_gender: {
        message: 'A specific epithet formed by an adjective ' \
                 'should agree in number and gender with the genus name',
        recommendations: %w[12.2]
      }.merge(@@link_to_edit_etymology),
      inconsistent_subspecies_grammatical_number_or_gender: {
        message: 'A subspecific epithet formed by an adjective ' \
                 'should agree in number and gender with the genus name ' \
                 '(see Rule 13b)',
        recommendations: %w[12.2]
      }.merge(@@link_to_edit_etymology),
      # - Rule 13a
      inconsistent_subspecies_name: {
        message: 'The first two epithets of subspecies names must correspond ' \
                 'to the parent species',
        rules: %w[13a]
      }.merge(@@link_to_edit_parent),
      malformed_subspecies_name: {
        message: 'Subspecies names should include the species name, ' \
                 'the abbreviation "subsp.", and the subspecies epithet',
        rules: %w[13a]
      }.merge(@@link_to_edit_spelling),
      # - Rule 13b covered in § Rule 8 and § Rule 12
      # - Rule 13c
      inconsistent_name_for_subspecies_with_type: {
        message: 'A subspecies including the type of the species must have ' \
                 'the same epithet',
        rules: %w[13c]
      }.merge(@@link_to_edit_spelling),
      # - Rule 14 covered in § Rule 8 and also:
      inconsistent_family_grammatical_number_or_gender: {
        message: 'A name in the rank of family must be feminine and plural',
        rules: %w[14]
      }.merge(@@link_to_edit_etymology),
      inconsistent_order_grammatical_number_or_gender: {
        message: 'A name in the rank of order must be feminine and plural',
        rules: %w[14]
      }.merge(@@link_to_edit_etymology),
      inconsistent_class_grammatical_number_or_gender: {
        message: 'A name in the rank of class must be neuter and plural',
        rules: %w[14]
      }.merge(@@link_to_edit_etymology),
      inconsistent_phylum_grammatical_number_or_gender: {
        message: 'A name in the rank of phylum must be neuter and plural',
        rules: %w[14]
      }.merge(@@link_to_edit_etymology),
      # - Rule 15
      incorrect_suffix: {
        message: lambda { |w|
          "The ending of the name is incompatible with the " +
            "rank of #{w.name.rank}"
        },
        rules: %w[15]
      }.merge(@@link_to_edit_spelling),
      inconsistent_etymology_with_type_genus: {
        message: lambda { |w|
          "The etymology should be formed by the stem of the type " +
            "genus and the suffix -#{w.name.rank_suffix}"
        },
        link_text: 'Autofill etymology',
        link_to: lambda { |w| [:autofill_etymology, w.name, method: :post] },
        rules: %w[15]
      },
      inconsistent_with_type_genus: {
        message: lambda { |w|
          "The name should be formed by adding the suffix " +
            "-#{w.name.rank_suffix} to the stem of the type genus"
        },
        rules: %w[15 16]
      }.merge(@@link_to_edit_spelling),

      # Section 4. Nomenclatural Types and Their Designation
      # - Rule 16 covered in § Rule 16 and also:
      missing_type: {
        message: 'The name is missing a type definition',
        rules: lambda { |w|
          %w[16 17 26.3] + (
            %w[subspecies species].include?(w.name.inferred_rank) ? %w[18a] :
              %w[genus].include?(w.name.inferred_rank) ? %w[21a] : []
          )
        }
      }.merge(@@link_to_edit_type),
      inconsistent_type_rank: {
        message: lambda { |w|
          "The nomenclatural type of a #{w.name.inferred_rank} must " +
            "be a designated #{w.name.expected_type_rank}"
        },
        rules: lambda { |w|
          %w[16] + (w.name.inferred_rank == 'genus' ? %w[21a] : [])
        }
      }.merge(@@link_to_edit_type),
      # - Rule 17 covered in § Rule 16
      # - Rule 18a covered in § Appendix I and also:
      unrecognized_type_material: {
        message: 'A sequence used as type material must be available ' \
                 'in the INSDC databases',
        rules: %w[18a 26.3]
      }.merge(@@link_to_edit_type),
      sequence_not_found: {
        message: 'A sequence used as type material must be available ' \
                 'in the INSDC databases',
        rules: %w[18a 26.3]
      }.merge(@@link_to_edit_type),
      # - Rule 18b [Checklist-G, TODO: issue #98]:
      #   The type of a species or subspecies must allow the unambiguous
      #   identification of the taxon. Names based on types that later prove to
      #   be ambiguous are not legitimate unless a neotype is proposed.
      ambiguous_type_genome: {
        checklist: :genomics,
        message: 'The type material must identify the taxon unambiguously',
        rules: %w[18b]
      }.merge(@@link_to_edit_type),
      # - Rule 18c requires the implementation of neotype designations
      #   [TODO: issue #12] no checks are to be implemented
      # - Rule 19 is implied by the SeqCode Registry structure
      # - Recommendation 19:
      missing_reference_strain: {
        message: 'A reference strain should be established when the type ' \
                 'genome is reported as derived from an isolate',
        recommendations: %w[19]
      }.merge(@@link_to_edit_type),
      unavailable_reference_strain: {
        message: 'If isolated, reference strains should be submitted to two ' \
                 'culture collections',
        recommendations: %w[19]
      }.merge(@@link_to_edit_type),
      #   When a strain belonging to a taxon named under the SeqCode is
      #   isolated, a reference strain should be designated and submitted to two
      #   culture collections in different countries. Reference strains have no
      #   standing in nomenclature.
      # - Rule 20
      non_valid_name_as_type: {
        message: 'Only a validly published name can be used as nomenclatural ' \
                 'type',
        rules: %w[20],
        can_endorse: true
      }.merge(@@link_to_edit_type),
      # - Rule 21a [Checklist-N]
      later_species_as_genus_type: {
        checklist: :nomenclature,
        message: 'The type of a genus must be the original type species',
        rules: %w[21a]
      }.merge(@@link_to_edit_type),
      # - Rule 21b [Checklist-N]
      different_type_after_genus_substitution: {
        checklist: :nomenclature,
        message: 'The type of a substituted genus name must remain unchanged',
        rules: %w[21b 22]
      }.merge(@@link_to_edit_type),
      # - Rule 22 [Checklist-N]
      #   TODO: An automated test could be included, but it would rely on the
      #         preferred taxonomy and would require estimates of priority dates
      #         for ICNP and ICN names. This would be very useful as the number
      #         of taxa grows larger.
      later_taxon_as_type: {
        checklist: :nomenclature,
        message: 'The nomenclatural type must be the earliest legitimate taxon',
        rules: %w[22]
      }.merge(@@link_to_edit_type),

      # Section 5. Priority and Valid Publication of Names
      # - Rule 23a [TODO: Checklist]:
      #   Any taxon with a given circumscription, position, and rank can bear
      #   only one correct name, the earliest name that is in accordance with
      #   the rules of SeqCode. {Includes two notes}
      # - Rules 23b and 23c are automatically enforced by the SeqCode Registry
      #   or require no additional checks
      # - Rule 23d [TODO: issue #97]
      # - Rule 23e is implied by the SeqCode Registry, but a comprehensive list
      #   of names should be automatically imported [TODO: issue #90]
      # - Rule 24a
      missing_effective_publication: {
        message: 'The publication proposing this name has not been identified',
        link_text: 'Register publication',
        link_to: lambda { |w| [:new_publication, { link_name: w.name.id }] },
        rules: %w[24a],
        can_endorse: true
      },
      # - Rule 24b [Checklist-N]
      unavailable_english_description: {
        checklist: :nomenclature,
        message: 'An English description is required for works in other ' \
                 'languages',
        rules: %w[24b]
      },
      # - Rule 24c
      invalid_effective_publication: {
        message: 'The publication proposing this name is a preprint or some ' \
                 'other type of publication not accepted',
        link_text: 'Register another publication',
        link_to: lambda { |w| [:new_publication, { link_name: w.name.id }] },
        rules: %w[24c]
      },
      # - Rule 25 is automatically enforced by SeqCode Registry
      #   (but see issue #97)
      # - Rule 26.1 is implied by the SeqCode Registry structure
      # - Rule 26.2
      missing_genome_kind: {
        message: 'The kind of genome used as type has not been specified',
        rules: %w[26.2]
      }.merge(@@link_to_edit_genome),
      missing_genome_source: {
        message: 'The source of the type genome has not been specified',
        rules: %w[26.2 appendix-i]
      }.merge(@@link_to_edit_genome),
      missing_genome_sequencing_depth: {
        message:
          'The sequencing depth of the type genome has not been specified',
        rules: %w[26.2 appendix-i]
      }.merge(@@link_to_edit_genome),
      missing_genome_completeness: {
        message: 'The completeness of the type genome has not been specified',
        rules: %w[26.2 appendix-i]
      }.merge(@@link_to_edit_genome),
      missing_genome_contamination: {
        message: 'The contamination of the type genome has not been specified',
        rules: %w[26.2 appendix-i]
      }.merge(@@link_to_edit_genome),
      # - Rule 26.3 covered in § Rule 16 and § Rule 18a
      # - Rule 26.4 covered in § Recommendation 7
      # - Rule 26.5
      missing_full_epithet_etymology: {
        message: 'The etymology of one or more particles is provided, but ' \
                 'the etymology of the full name or epithet is missing',
        rules: %w[26.5]
      }.merge(@@link_to_edit_etymology),
      missing_etymology: {
        message: 'The etymology of the name has not been provided',
        rules: %w[26.5]
      }.merge(@@link_to_edit_etymology),
      # - Rule 26.5 [Checklist-N, in addition to the above]
      missing_roots_from_existing_languages: {
        checklist: :nomenclature,
        message: 'Distinguishable roots from existing languages must be ' \
                 'identified',
        rules: %w[26.5]
      }.merge(@@link_to_edit_etymology),
      # - Recommendation 26 [Checklist-N]
      missing_description_in_publication: {
        checklist: :nomenclature,
        message: 'A clear description and/or protologue should be available ' \
                 'in the effective publication',
        recommendations: %w[26]
      },
      missing_metadata_in_databases: {
        checklist: :genomics,
        message: 'Descriptive metadata should be available in INSDC databases',
        recommendations: %w[26]
      }.merge(@@link_to_edit_genome),
      # - Rule 27 requires addressing new combinations [TODO: issue #30],
      #   but it would not require additional checks

      # Section 6. Citation of Authors and Names
      # - Recommendation 28 is followed by SeqCode Registry structure
      # - Rule 29 [TODO: issue #30]
      # - Recommendation 30 [Checklist-N]
      missing_publication_of_emendation: {
        checklist: :nomenclature,
        message: 'Significant emendations should be properly cited',
        recommendations: %w[30],
        link_text: 'Register publication',
        link_to: lambda { |w| [:new_publication, { link_name: w.name.id }] }
      },

      # Section 7. Changes in Names of Taxa as a Result of Transference, Union,
      # or Change in Rank
      # 
      # This complete section is yet to be supported by SeqCode Registry
      # actions [TODO: issue #30]
      # - Rule 31
      # - Rule 32
      # - Rule 33
      # - Rule 34a
      # - Rule 34b
      # - Rule 34c
      # - Rule 35a
      # - Rule 35b
      # - Rule 35c
      # - Rule 36
      # - Rule 37
      # - Rule 38
      # - Rule 39
      # - Rule 40
      # - Rule 41a
      # - Rule 41b
      # - Rule 41c

      # Section 8. Illegitimate Names and Epithets: Replacement, Rejection, and
      # Conservation of Names and Epithets
      # 
      # This section primarily deals with actions to be taken by the SeqCode
      # Reconciliation Comission, and do not require actions from curators or
      # users (but see also issue #30)
      # - Rule 42
      # - Rule 43
      # - Rule 44
      # - Rule 45

      # Section 9. Orthography
      # - Rule 46 covered in § Rule 8
      # - Rule 47 [Checklist-N]
      incorrect_spelling: {
        checklist: :nomenclature,
        message: 'Name should conform original spelling and Latin grammar',
        rules: %w[47]
      }.merge(@@link_to_edit_spelling),
      # - Rule 48 is followed by the SeqCode Registry, and also:
      corrigendum_affecting_initials: {
        message: 'A corrigendum should be issued with reserve when affecting ' \
                 'the first letter of a name',
        rule_notes: %w[48]
      }.merge(@@link_to_edit_spelling),
      # - Rule 49 [TODO: Checklist, see also § Recommendation 9.2 and issue #6]:
      #   The genitive and adjectival forms of a personal name are treated as
      #   different epithets and not as orthographic variants unless they are so
      #   similar as to cause confusion.
      # - Rule 50.1
      missing_grammatical_gender: {
        message: 'Authors must give the gender of any proposed genus name',
        rules: %w[50.1 50.3]
      }.merge(@@link_to_edit_etymology),
      # - Rule 50.1 [Checklist-N, in addition to the above]:
      grammatical_gender_varies_from_source: {
        checklist: :nomenclature,
        message: 'A Latinized genus name should retain the original gender',
        rules: %w[50.1]
      }.merge(@@link_to_edit_etymology),
      # - Rule 50.2
      inconsistent_grammatical_gender: {
        message: 'A genus name formed by two or more Latin words should take ' \
                 'gender of the last component of the word',
        rules: %w[50.2]
      }.merge(@@link_to_edit_etymology),
      # - Rule 50.3 covered in § Rule 50.1

      # APPENDIX I
      low_genome_sequencing_depth: {
        message:
          'The sequencing depth of the type genome should be 10X or greater',
        rules: %w[18a appendix-i]
      }.merge(@@link_to_edit_genome),
      low_genome_completeness: {
        message: 'The completeness of the type genome should be above 90%',
        rules: %w[18a appendix-i]
      }.merge(@@link_to_edit_genome),
      high_genome_contamination: {
        message: 'The contamination of the type genome should be below 5%',
        rules: %w[18a appendix-i]
      }.merge(@@link_to_edit_genome),
      inconsistent_16s_assignment: {
        checklist: :genomics,
        message: 'The 16S rRNA genes should agree with the genome taxonomy',
        rules: %w[18a appendix-i]
      }.merge(@@link_to_edit_genome),
      low_genome_16s_count: {
        message: 'At least one 16S rRNA gene should be identified',
        recommendations: %w[appendix-i]
      }.merge(@@link_to_edit_genome),
      low_genome_16s_completeness: {
        message: '16S rRNA genes should be more than 75% complete',
        recommendations: %w[appendix-i]
      }.merge(@@link_to_edit_genome),
      low_genome_trnas_completeness: {
        message: 'The type genome should contain more than 80% of tRNAs',
        recommendations: %w[appendix-i]
      }.merge(@@link_to_edit_genome),
    }

    attr_accessor :type, :name
    attr_writer *@@attributes

    @@attributes.each do |k|
      define_method(k) do
        v = instance_variable_get("@#{k}")
        v.is_a?(Proc) ? v.call(self) : v
      end
    end

    def initialize(type, opts)
      @type = type.to_sym
      defaults.each { |k, v| send("#{k}=", v) }
      opts.each { |k, v| send("#{k}=", v) }
    end

    def defaults
      @@defaults[type] || {}
    end

    def title
      type.to_s.gsub(/_/, ' ').capitalize
          .gsub('english', &:capitalize)
    end

    def is_error?
      rules.present? && (!can_endorse || name.notified?)
    end

    def fail
      is_error? ? :error : :warn
    end

    def check
      name.check(type)
    end

    def bypassed?
      !checklist && check&.pass?
    end

    def to_hash
      Hash[
        @@attributes.map do |k|
          next if k.to_s =~ /^link_/
          v = send(k)
          [k, v] unless v.nil?
        end.compact
      ]
    end

    def [](k)
      send(k)
    end
  end # QcWarning

  class QcWarningSet
    attr_accessor :name, :set, :checks

    def initialize(name)
      @name = name
      @set_h = {}
      @checks_h = {}
      @bypassed_h = {}
    end

    def add(type, opts = {})
      qc = QcWarning.new(type, opts.merge(name: name))
      @checks_h[qc.type] = qc if qc.checklist
      if (!qc.checklist && !qc.check) || (qc.check && qc.check.fail?)
        @set_h[qc.type] = qc
      elsif qc.bypassed?
        @bypassed_h[qc.type] = qc
      end
    end

    def set
      @set_h.values
    end

    def checks
      @checks_h.values
    end

    def checked_checks
      @checks_h.values.select(&:check)
    end

    def bypassed
      @bypassed_h.values
    end

    def resort!
      new_set_h = @set_h
      new_checks_h = @checks_h
      @set_h = {}
      @checks_h = {}
      QcWarning.defaults.each_key do |k|
        @set_h[k]   = new_set_h[k]     if new_set_h[k]
        @checks_h[k] = new_checks_h[k] if new_checks_h[k]
      end
    end

    def map(&blk)
      set.map(&blk)
    end

    def each(&blk)
      set.each(&blk)
    end

    def select(&blk)
      set.select(&blk)
    end

    def empty?
      set.empty?
    end

    def errors?
      !set.empty? && set.any?(&:is_error?)
    end
  end # QcWarningSet

  ##
  # Test all relevant quality checks and return the QC warnings
  # as a Hash
  def qc_warnings
    return @qc_warnings unless @qc_warnings.nil?

    @qc_warnings = QcWarningSet.new(self)
    return @qc_warnings if inferred_rank == 'domain'

    @qc_warnings.add(:candidatus_modifier) if candidatus?
    @qc_warnings.add(:missing_rank) unless rank?
    @qc_warnings.add(:identical_base_name) unless identical_base_name.nil?
    @qc_warnings.add(:identical_external_name) unless external_homonyms.empty?
    @qc_warnings.add(:missing_description) unless description?
    @qc_warnings.add(:invalid_effective_publication) if proposed_in&.prepub?
    @qc_warnings.add(:missing_publication_of_emendation) # check
    if proposed_in.nil? &&
        (register.nil? || register.notified? || register.validated?)
      @qc_warnings.add(:missing_effective_publication)
    end

    if proposed_in
      @qc_warnings.add(:missing_description_in_publication) # check
      @qc_warnings.add(:unavailable_english_description) # check
    end

    unless base_name =~ /\A[A-Z][a-z ]+( subsp\. )?[a-z ]+\z/
      @qc_warnings.add(:inconsistent_format)
    end

    @qc_warnings.add(:incorrect_suffix) unless correct_suffix?

    if !type?
      @qc_warnings.add(:missing_type)
    elsif %w[species subspecies].include?(inferred_rank) &&
          !%w[nuccore assembly].include?(type_material)
      @qc_warnings.add(:unrecognized_type_material)
    end

    if type_is_name? && !type_name.validated?
      @qc_warnings.add(:non_valid_name_as_type)
    end

    if type_is_genome?
      @qc_warnings.add(:ambiguous_type_genome) # check
      if genome.isolate? && !genome_strain?
        @qc_warnings.add(:missing_reference_strain)
      end
      if genome_strain? && genome_strain_collections < 2
        @qc_warnings.add(:unavailable_reference_strain)
      end
      @qc_warnings.add(:missing_genome_kind) unless type_genome.kind.present?
      @qc_warnings.add(:sequence_not_found) if type_genome.auto_failed.present?

      if type_genome.source?
        @qc_warnings.add(:missing_metadata_in_databases) # check
      else
        if proposed_in && proposed_in.journal_date.year < 2023
          # Only a warning for publications before 1st January 2023
          @qc_warnings.add(
            :missing_genome_source,
            rules: [],
            recommendations: %w[appendix-i],
          )
        else
          @qc_warnings.add(:missing_genome_source)
        end
      end

      # Sequencing depth checks
      seq_depth_extra = {}
      if type_genome.mag_or_sag?
        # Sequencing depth (≥10x) is only a recommendation for MAGs/SAGs
        seq_depth_extra = { recommendations: %w[appendix-i], rules: [] }
      end

      if !type_genome.seq_depth?
        @qc_warnings.add(:missing_genome_sequencing_depth, seq_depth_extra)
      elsif type_genome.seq_depth < 10.0
        @qc_warnings.add(:low_genome_sequencing_depth, seq_depth_extra)
      end

      # Completeness and contamination are only required for MAGs/SAGs
      if type_genome.mag_or_sag?
        if !type_genome.completeness_any?
          @qc_warnings.add(:missing_genome_completeness)
        elsif type_genome.completeness_any <= 90.0
          @qc_warnings.add(:low_genome_completeness)
        end

        if !type_genome.contamination_any?
          @qc_warnings.add(:missing_genome_contamination)
        elsif type_genome.contamination_any >= 5.0
          @qc_warnings.add(:high_genome_contamination)
        end
      end # type_genome.mag_or_sag?

      if type_genome.number_of_16s_any? &&
         !type_genome.number_of_16s_any.zero?
        @qc_warnings.add(:inconsistent_16s_assignment) # check
      end

      if type_genome.number_of_16s_any? &&
         type_genome.number_of_16s_any.zero?
        @qc_warnings.add(:low_genome_16s_count)
      elsif type_genome.most_complete_16s_any? &&
         type_genome.most_complete_16s_any <= 75.0
        @qc_warnings.add(:low_genome_16s_completeness)
      end

      if type_genome.number_of_trnas_any?
        if type_genome.number_of_trnas_any <= 16
          @qc_warnings.add(:low_genome_trnas_completeness)
        elsif type_genome.number_of_trnas_any > 21 # 20 standard + SeC
          @qc_warnings.add(:too_many_amino_acids)
        end
      end

      # Measure discrepancy with automated checks
      Genome.fields_with_auto.each do |field|
        next if field == :quality
        any  = type_genome.send(:"#{field}_any") or next
        auto = type_genome.send(:"#{field}_auto") or next
        next unless any.is_a? Numeric

        diff = (any - auto).abs.to_f / [any, auto].max
        if diff > 0.1 && (any - auto).abs >= 1.0
          # Ignore if the automated estimates pass minimum quality
          next if field == :completeness  && auto > 90.0
          next if field == :contamination && auto <  5.0

          @qc_warnings.add(:"discrepant_#{field}") if diff > 0.1
        end
      end
    end # type_is_genome?


    @qc_warnings.add(:inconsistent_type_rank) unless consistent_type_rank?

    unless !rank? || top_rank? || incertae_sedis? || !parent.nil?
      @qc_warnings.add(:missing_parent)
    end

    @qc_warnings.add(:inconsistent_parent_rank) unless consistent_parent_rank?

    if rank?
      if rank == 'species' && base_name !~ / /
        @qc_warnings.add(:unary_species_name)
      end

      if rank == 'subspecies' &&
         base_name !~ /\A[A-Z][a-z]* [a-z]+ subsp\. [a-z]+\z/
        @qc_warnings.add(:malformed_subspecies_name)
      end

      if !%w[species subspecies].include?(rank) && base_name =~ / /
        @qc_warnings.add(:binary_name_above_species)
      end

      if rank == 'genus'
        if self.class.rank_regexps.any? { |_, i| name =~ i }
          @qc_warnings.add(:reserved_suffix)
        end
        @qc_warnings.add(:later_species_as_genus_type) if type? # check
        @qc_warnings.add(:different_type_after_genus_substitution) # check
      end
    end

    @qc_warnings.add(:inconsistent_language) if etymology? && !latin?
    unless consistent_syllabication?
      @qc_warnings.add(:inconsistent_syllabification)
    end

    unless consistent_with_type_genus?
      @qc_warnings.add(:inconsistent_with_type_genus)
    end

    unless consistent_etymology_with_type_genus?
      @qc_warnings.add(:inconsistent_etymology_with_type_genus)
    end

    @qc_warnings.add(:long_name) if long_word?
    @qc_warnings.add(:difficult_to_pronounce) if hard_to_pronounce?

    if rank? && %w[species subspecies].include?(rank)
      unless consistent_species_name?
        @qc_warnings.add(:inconsistent_species_name)
      end

      unless consistent_subspecies_name?
        @qc_warnings.add(:inconsistent_subspecies_name)
      end

      unless consistent_grammar_for_species_or_subspecies?
        @qc_warnings.add(:"inconsistent_grammar_for_#{rank}_name")
      end

      unless consistent_name_for_subspecies_with_type?
        @qc_warnings.add(:inconsistent_name_for_subspecies_with_type)
      end
    end

    if rank? && above_rank?(:family)
      @qc_warnings.add(:later_taxon_as_type) if type? # check
    end

    if etymology?
      if etymology(:p1, :grammar) && !etymology(:xx, :grammar)
        @qc_warnings.add(:missing_full_epithet_etymology)
      end
      if any_non_latin?
        @qc_warnings.add(:latin_should_be_preferred) # check
      end
      if inferred_rank == 'genus' && !feminine?
        @qc_warnings.add(:personal_genus_must_be_feminine) # check
      end
      if %w[species subspecies].include?(inferred_rank)
        @qc_warnings.add(:inconsistent_epithet_relationship_to_genus) # check
      end
      if rank? && rank == 'genus'
        @qc_warnings.add(:grammatical_gender_varies_from_source) # check
      end

      @qc_warnings.add(:inapt_personal_name) # check
      @qc_warnings.add(:contentious_name) # check
      @qc_warnings.add(:lacking_mnemonic_cues) # check
      @qc_warnings.add(:incorrect_spelling) # check
      @qc_warnings.add(:missing_roots_from_existing_languages) # check
    else
      @qc_warnings.add(:missing_etymology)
    end

    @qc_warnings.add(:unspecific_epithet) if inferred_rank == 'species' # check

    unless consistent_genus_gender?
      if feminine? || masculine? || neuter?
        @qc_warnings.add(:inconsistent_grammatical_gender)
      else
        @qc_warnings.add(:missing_grammatical_gender)
      end
    end

    unless consistent_grammatical_number_and_gender?
      @qc_warnings.add(
        :"inconsistent_#{inferred_rank}_grammatical_number_or_gender"
      )
    end

    if corrigendum_from &&
         corrigendum_from.sub(/^Candidatus /, '')[0] != base_name[0]
      @qc_warnings.add(:corrigendum_affecting_initials)
    end

    @qc_warnings.resort!
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
    regexp = self.class.rank_regexps[rank.to_s.to_sym]
    return true if regexp.nil? # domain, genus, species, subspecies, undefined

    name =~ regexp
  end

  def consistent_parent_rank?
    return true if !rank? || parent.nil? || !parent.rank?

    self.class.ranks.index(rank) == self.class.ranks.index(parent.rank) + 1
  end

  def consistent_type_rank?
    return true if !rank? || !type_is_name?

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
    genders = %i[feminine? masculine? neuter?]

    return true unless rank? && grammar && rank == 'genus'

    # Rule 50.1
    # Gender must be defined and unique for the full epithet
    return false if genders.select { |i| send(i) }.count != 1

    # Rules 50.1 and 50.3
    # If it's not a compound word, no further checks are necessary
    return true if [:p1, nil].include?(last_component)

    # Rule 50.1 and 50.3
    # If the last component is not Latin or has no defined gender,
    # no further checks are necessary
    return true unless latin?(last_component) && gender?(last_component)

    # Rule 50.2
    # Check if the gender between the last component and the full epithet
    # coincide. Note that we use +any?+ to account for components with
    # multiple possible genders (e.g., 'fem. or masc.')
    genders.any? { |i| send(i) && send(i, last_component) }
  end

  def consistent_grammatical_number_and_gender?
    return true if !rank? || !grammar

    case rank
    when 'genus'
      (!plural?) && (adjective? || noun?)
    when 'species', 'subspecies'
      return true unless genus&.grammar # If it cannot be checked
      return true unless adjective? # Only adjectives are checked

      # Recommendation 12.2, Rule 13b
      return false unless genus.plural? == plural?
      genders = %i[masculine? feminine? neuter?]
      genders.any? { |x| genus.send(x) && send(x) }
    when 'family', 'order'
      feminine? && plural?
    when 'class', 'phylum'
      neuter? && plural?
    else
      true
    end
  end

  def consistent_grammar_for_species_or_subspecies?
    return true if !rank? || !%w[species subspecies].include?(rank) || !grammar

    # adjective? Rule 12.1 for species, 13b for subspecies
    # noun? Rule 12.2 / 12.3 for species, 13b for subspecies
    adjective? || noun?
  end

  def consistent_name_for_subspecies_with_type?
    return true if !rank? || rank != 'subspecies' || !type? || !parent&.type?

    # If it's based on the same type as the parent species, it must bear the
    # same epithet
    (type_text != parent.type_text) || (last_epithet == parent.last_epithet)
  end

  def consistent_with_type_genus?
    return true unless rank? && type_is_name? && rank != 'genus'
    return true unless rank_suffix

    root = base_name.sub(/#{rank_suffix}$/, '')
    root == genus_root(type_name.base_name)
  end

  def consistent_etymology_with_type_genus?
    return true unless rank? && type_is_name? && type_name.rank == 'genus'

    first_particle = etymology(:p1, :particle)
    first_particle ? type_name.base_name == first_particle : true
  end

  def consistent_syllabication?
    return true unless syllabication?

    last_epithet.downcase == syllabication.gsub(/[^A-Za-z]/, '').downcase
  end
end
