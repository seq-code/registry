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

    when /chloro[sn]$/
      # - Petrachloros -- Petrachlor-aceae
      # - Prochloron -- Prochlor-aceae
      base.sub!(/o[sn]$/, '')
    when /comes$/
      # - Porifericomes -- Porifericom-it-aceae
      base.sub!(/es$/, 'it')
    when /[ck]orys$/
      # - Myxacorys -- 
      base.sub!(/ys$/, '')
    when /(desmis|glans|opsis|physalis|pyxis)$/
      # - Phormidesmis -- Phormidesmi-d-aceae
      # - Desulfatiglans -- Desulfatiglan-d-aceae
      # - Coelosphaeriopsis -- 
      # - Hapalopsis -- 
      # - Lyngbyopsis --
      # - Entophysalis -- Entophysali-d-aceae
      # - Sphingopyxis -- Sphingopyxi-d-aceae
      base.sub!(/s$/, 'd')
    when /glomus$/
      # - Dictryoglomus -- Dictyoglom-er-aceae
      base.sub!(/us$/, 'er')
    when /myces$/
      # - Actinomyces -- Actinomyce-t-aceae
      base.sub!(/s$/, 't')
    when /plasma$/
      # - Acholeplasma -- Acholeplasma-t-aceae
      # Counterexamples:
      # - Ferroplasma -- Ferroplasm-aceae (irregularly formed)
      base.sub!(/plasma$/, 'plasmat')
    when /pulchritudo$/
      # - Oceanipulchritudo -- Oceanipulchritud-in-aceae
      base.sub!(/o$/, 'in')
    when /thrix$/
      # - Erysipelothrix -- Erysipelotri-ch-aceae
      # - Caldithrix -- Calditri-ch-aceae
      # - Thiothrix -- Thiotri-ch-aceae
      # Counterexamples:
      # - Thermosporothrix -- Thermosporothri-ch-aceae
      base.sub!(/thrix$/, 'trich')

    # Common exception endings (covering groups of morphemes)

    when /aeum$/
      # - Methanonatronarchaeum -- Methanonatroarchae-aceae
      base.sub!(/um$/, '')
    when /[aeiou]ns$/
      # - Myceligenerans -- 
      # - Jatrophihabitans -- Jatrophihabitan-t-aceae
      # - Hopanoidivorans -- Hopanoidivoran-t-aceae
      # - Saccharicenans -- Saccharicenan-t-aceae
      # - Hydrogenedens -- Hydrogeneden-t-aceae
      # - Methanoflorens -- Methanofloren-t-aceae
      # - Aquivivens -- Aquiviven-t-aceae
      base.sub!(/ns$/, 'nt')
    when /u[ms]$/
      # - Acidaminococcus -- Acidaminococc-aceae
      # - Acidilobus -- Acidilob-aceae
      # - Acidimicrobium -- Acidimicrobi-aceae
      # - Eubacterium -- Eubacteri-aceae
      base.sub!(/u[ms]$/, '')
    when /[stl]is$/
      # - Nocardiopsis -- Nocardiops-aceae
      # - Methylocystis -- Methylocyst-aceae
      # - Maricaulis -- Maricaulaceae
      base.sub!(/is$/, '')
    when /[nr][ai]s$/
      # - Aeromonas -- Aeromona-d-aceae
      # - Alteromonas -- Alteromona-d-aceae
      # - Blastochloris -- Blastochlori-d-aceae
      # Counterexamples:
      # - Catalinimonas -- Catali-mona-d-aceae (irregularly formed)
      base.sub!(/s$/, 'd')
    when /[eoy]ma$/
      # - Brevinema -- Brevinema-t-aceae
      # - Deferrisoma -- Deferrisoma-t-aceae
      # - Tropheryma -- Tropheryma-t-aceae
      # Counterexamples:
      # - Spirosoma -- Spirosoma-ceae (irregularly formed)
      base.sub!(/ma$/, 'mat')
    when /[aeiou]s$/
      # - Desulfallas -- Desulfall-aceae
      # - Alcaligenes -- Alcaligen-aceae
      # - Desulfocucumis -- Desulfocucum-aceae
      # - Rhodoligotrophos -- Rodoligotroph-aceae
      # - Petrachloros -- Petrachlor-aceae (already captured above)
      # - Other examples from /u[ms]$/ (already captured above)
      base.sub!(/[aeiou]s$/, '')
    when /ys$/
      # - Labrys --
      # - Pseudolabrys --
      base.sub!(/s$/, '')
    when /non$/
      # - Caryophanon -- Caryophan-aceae
      base.sub!(/on$/, '')

    # Standard endings

    when /ue$/
      # - Kallotenue -- Kallotenu-aceae
      base.sub!(/e$/, '')
    when /[ae]$/
      # - Actinochlamydia -- Actinochlamydi-aceae
      # - Actinopolymorpha -- Actinopolymorph-aceae
      # - Aestuariivirga -- Aestuariivirg-aceae
      # - Afifella -- Afifell-aceae
      # - Aggregatilinea -- Aggregatiline-aceae
      # - Aliterella -- Aliterell-aceae
      # - Desulfomonile -- Desulfomonil-aceae
      base.sub!(/[ae]$/, '')
    when /io$/
      # - Vibrio -- Vibrio-n-aceae
      # - Cellvibrio -- Cellvibrio-n-aceae
      base.sub!(/io$/, 'ion')
    when /ex$/
      # - Aquifex -- Aquif-ic-aceae
      base.sub!(/ex$/, 'ic')
    when /x$/
      # - Adiutrix -- Adiutri-c-aceae
      # - Alcanivorax -- Alcanivora-c-aceae
      # Counterexamples:
      # - Balneatrix -- Balneatri-ch-aceae (irregularly formed)
      # - Thiotrix -- Thiotri-ch-aceae (illegitimate?)
      # - Halobacteriovorax -- Halobacteriovor-aceae (irregularly formed)
      # - Proteinivorax -- Proteinivor-aceae (irregularly formed)
      base.sub!(/x$/, 'c')
    end

    # Other cases:
    # *bacter sometimes form *bacter-i-aceae and sometimes *bacter-aceae
    # names, we're using the latter.

    base
  end
end

