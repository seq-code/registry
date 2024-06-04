module Name::Inferences
  def stem
    @stem ||=
      if inferred_rank == 'genus'
        genus_root(base_name)
      elsif inferred_rank == 'domain'
        nil
      elsif type_is_name?
        type_name.stem
      end
  end

  def genus_root(base)
    case base # Genus name

    # Particular morpheme exceptions

    when /pulchritudo$/
      # - Oceanipulchritudo -- Oceanipulchritud-in-aceae
      base.gsub!(/o$/, 'in')
    when /(opsis|physalis|glans|desmis)$/
      # - Coelosphaeriopsis -- 
      # - Hapalopsis -- 
      # - Lyngbyopsis --
      # - Entophysalis -- Entophysali-d-aceae
      # - Desulfatiglans -- Desulfatiglan-d-aceae
      # - Phormidesmis -- Phormidesmi-d-aceae
      base.gsub!(/s$/, 'd')
    when /glomus$/
      # - Dictryoglomus -- Dictyoglom-er-aceae
      base.gsub!(/us$/, 'er')
    when /chloro[sn]$/
      # - Petrachloros -- Petrachlor-aceae
      # - Prochloron -- Prochlor-aceae
      base.gsub!(/o[sn]$/, '')
    when /(ta|vive|vora|flore)ns$/
      # - Jatrophihabitans -- Jatrophihabitan-t-aceae
      # - Aquivivens -- Aquiviven-t-aceae
      # - Hopanoidivorans -- Hopanoidivoran-t-aceae
      # - Methanoflorens -- Methanofloren-t-aceae
      base.gsub!(/ns$/, 'nt')
    when /myces$/
      # - Actinomyces -- Actinomyce-t-aceae
      base.gsub!(/s$/, 't')
    when /plasma$/
      # - Acholeplasma -- Acholeplasma-t-aceae
      # Counterexamples:
      # - Ferroplasma -- Ferroplasm-aceae (irregularly formed)
      base.gsub!(/plasma$/, 'plasmat')
    when /comes$/
      # - Porifericomes -- Porifericom-it-aceae
      base.gsub!(/es$/, 'it')
    when /thrix$/
      # - Erysipelothrix -- Erysipelotri-ch-aceae
      # - Caldithrix -- Calditri-ch-aceae
      # - Thiothrix -- Thiotri-ch-aceae
      # Counterexamples:
      # - Thermosporothrix -- Thermosporothri-ch-aceae
      base.gsub!(/thrix$/, 'trich')

    # Common exception endings (covering groups of morphemes)

    when /aeum$/
      # - Methanonatronarchaeum -- Methanonatroarchae-aceae
      base.gsub!(/um$/, '')
    when /u[ms]$/
      # - Acidaminococcus -- Acidaminococc-aceae
      # - Acidilobus -- Acidilob-aceae
      # - Acidimicrobium -- Acidimicrobi-aceae
      # - Eubacterium -- Eubacteri-aceae
      base.gsub!(/u[ms]$/, '')
    when /[stl]is$/
      # - Nocardiopsis -- Nocardiops-aceae
      # - Methylocystis -- Methylocyst-aceae
      # - Maricaulis -- Maricaulaceae
      base.gsub!(/is$/, '')
    when /[nr][ai]s$/
      # - Aeromonas -- Aeromona-d-aceae
      # - Alteromonas -- Alteromona-d-aceae
      # - Blastochloris -- Blastochlori-d-aceae
      # Counterexamples:
      # - Catalinimonas -- Catali-mona-d-aceae (irregularly formed)
      base.gsub!(/s$/, 'd')
    when /[eoy]ma$/
      # - Brevinema -- Brevinema-t-aceae
      # - Deferrisoma -- Deferrisoma-t-aceae
      # - Tropheryma -- Tropheryma-t-aceae
      # Counterexamples:
      # - Spirosoma -- Spirosoma-ceae (irregularly formed)
      base.gsub!(/ma$/, 'mat')
    when /[eai]s$/
      # - Alcaligenes -- Alcaligen-aceae
      # - Desulfallas -- Desulfall-aceae
      # - Desulfocucumis -- Desulfocucum-aceae
      base.gsub!(/[eai]s$/, '')
    when /non$/
      # - Caryophanon -- Caryophan-aceae
      base.gsub!(/on$/, '')

    # Standard endings

    when /ue$/
      # - Kallotenue -- Kallotenu-aceae
      base.gsub!(/e$/, '')
    when /[ae]$/
      # - Actinochlamydia -- Actinochlamydi-aceae
      # - Actinopolymorpha -- Actinopolymorph-aceae
      # - Aestuariivirga -- Aestuariivirg-aceae
      # - Afifella -- Afifell-aceae
      # - Aggregatilinea -- Aggregatiline-aceae
      # - Aliterella -- Aliterell-aceae
      # - Desulfomonile -- Desulfomonil-aceae
      base.gsub!(/[ae]$/, '')
    when /io$/
      # - Vibrio -- Vibrio-n-aceae
      # - Cellvibrio -- Cellvibrio-n-aceae
      base.gsub!(/io$/, 'ion')
    when /ex$/
      # - Aquifex -- Aquif-ic-aceae
      base.gsub!(/ex$/, 'ic')
    when /x$/
      # - Adiutrix -- Adiutri-c-aceae
      # - Alcanivorax -- Alcanivora-c-aceae
      # Counterexamples:
      # - Balneatrix -- Balneatri-ch-aceae (irregularly formed)
      # - Thiotrix -- Thiotri-ch-aceae (illegitimate?)
      # - Halobacteriovorax -- Halobacteriovor-aceae (irregularly formed)
      # - Proteinivorax -- Proteinivor-aceae (irregularly formed)
      base.gsub!(/x$/, 'c')
    end

    # Other cases:
    # *bacter sometimes form *bacter-i-aceae and sometimes *bacter-aceae
    # names, we're using the latter.

    base
  end
end

