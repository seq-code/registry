module Name::Etymology
  ##
  # Pull the component identified as +component+ from the name, and return
  # the field +field+
  #
  # Supported +component+ values (as Symbol) include +:xx+ or +:full+ for the
  # complete name or epithet, or +:p1+, +:p2+, ..., +:p5+ for each of the
  # particles
  def etymology(component, field)
    component = component.to_sym
    component = :xx if component == :full
    field = field.to_sym
    if component == :xx && field == :particle
      last_epithet
    else
      y = send(:"etymology_#{component}_#{field}")
      y.nil? || y.empty? ? nil : y
    end
  end

  def etymology?
    return true if etymology_text?

    self.class.etymology_particles.any? do |i|
      self.class.etymology_fields.any? do |j|
        next if i == :xx && j == :particle

        etymology(i, j)
      end
    end
  end

  def full_etymology(html = false)
    if etymology_text?
      y = etymology_text.body
      return(html ? y : y.to_plain_text)
    end

    y = Name.etymology_particles.map do |component|
      partial_etymology(component, html)
    end.compact.join('; ')
    y.empty? ? nil : html ? y.html_safe : y
  end

  def partial_etymology(component, html = false)
    pre = [etymology(component, :lang), etymology(component, :grammar)].compact.join(' ')
    pre = nil if pre.empty?
    par = etymology(component, :particle)
    des = etymology(component, :description)
    if html
      pre = "<b>#{pre}</b>" if pre
      par = "<i>#{par}</i>" if par
    end
    y = [[pre, par].compact.join(' '), des].compact.join(', ')
    y.empty? ? nil : html ? y.html_safe : y
  end

  def last_component
    parts = (self.class.etymology_particles - [:xx]).reverse
    parts.find { |i| self.class.etymology_fields.any? { |j| etymology(i, j) } }
  end

  def grammar(component = :xx)
    etymology(component, :grammar)
  end

  def grammar_has?(regex, component = :xx)
    return nil unless grammar(component)

    !!(grammar(component) =~ /(^| )#{regex}( |$)/)
  end

  def adjective?(component = :xx)
    grammar_has?(/adj(\.|ective)/, component)
  end

  def noun?(component = :xx)
    grammar_has?(/(n(\.|oun)|s(\.|ubst(\.|antive)))/, component)
  end

  def feminine?(component = :xx)
    grammar_has?(/fem(\.|inine)/, component)
  end

  def masculine?(component = :xx)
    grammar_has?(/masc(\.|uline)/, component)
  end

  def neuter?(component = :xx)
    grammar_has?(/neut(\.|er)/, component)
  end

  def plural?(component = :xx)
    grammar_has?(/pl(\.|ural)/, component)
  end

  def language(component = :xx)
    etymology(component, :lang)
  end

  def latin?(component = :xx)
    language(component) ? %w[L. N.L.].include?(language(component)) : nil
  end

  ##
  # Remove all the individual etymology fields from the current instance
  # *without* saving the changes to the database
  def clean_etymology
    self.class.etymology_particles.any? do |i|
      self.class.etymology_fields.any? do |j|
        self.send("etymology_#{i}_#{j}=", nil) unless i == :xx && j == :particle
      end
    end
  end

  def importable_etymology
    return nil unless %w[species subspecies].include?(rank)

    @importable_etymology ||=
      Name.where('name LIKE ?', "% #{last_epithet}")
          .where.not(id: id)
          .where.not(etymology_xx_grammar: [nil, ''])
          .last
  end

  ##
  # Can the etymology be automatically filled on the basis of the type genus?
  def can_autofill_etymology?
    return false unless rank?
    (type_is_name? && type_name.rank == 'genus') || !importable_etymology.nil?
  end

  ##
  # Attempt automatically fill the etymology on the basis of the type genus. It
  # affects the current instance but does not save changes to the database!
  def autofill_etymology
    self.syllabication = guess_syllabication unless syllabication?
    return unless can_autofill_etymology?

    clean_etymology
    if type_is_name? && type_name.rank == 'genus'
      # Based on type genus
      self.etymology_p1_lang = type_name.language
      self.etymology_p1_grammar = type_name.grammar
      self.etymology_p1_particle = type_name.base_name
      self.etymology_p1_description =
        "referring to the type #{type_name.rank} #{type_name.base_name}"
      self.etymology_p2_lang = 'L.'
      gen = %w[family order].include?(rank) ? 'fem.' : 'neut.'
      self.etymology_p2_grammar = "#{gen} pl. suff."
      self.etymology_p2_particle = "-#{rank_suffix}"
      self.etymology_p2_description =
        "ending to denote #{rank[0] =~ /[aeiou]/ ? 'an' : 'a'} #{rank}"
      self.etymology_xx_lang = 'N.L.'
      self.etymology_xx_grammar = "#{gen} pl. n."
      self.etymology_xx_description = "the #{type_name.base_name} #{rank}"
    else
      # Based on another (sub)species with the same epithet
      self.class.etymology_particles.each do |i|
        self.class.etymology_fields.each do |j|
          next if i == :xx && j == :particle

          acc = "etymology_#{i}_#{j}"
          self.send("#{acc}=", importable_etymology.send(acc))
        end
      end
    end
  end

  ##
  # Guess the syllabification of the last epithet (or any +word+ passed)
  # mostly following the rules in https://marello.org/tools/syllabifier/
  #
  # Modifications:
  # - The digraphs ae and oe are parsed as a single vowel
  # - The following digraphs starting a syllable are considered a single
  #   consonant: ps, pt, ts, and tz
  # - The following digraphs are also consider single consonants:
  #   zh, sh, gh, rh, ll, tt, ck
  # - The rules above don't explicitly define a vowel. Appart from the
  #   above digraphs, the letters a, e, i, o, and u are considered vowels,
  #   as well as the letter y except at the beginning of a word
  def guess_syllabication(word = last_epithet)
    pos = 0
    syllables = ['']
    vowel = /[aeiouy]/i
    # Wheelock's Latin provides this sound exception:
    # Also counted as single consonants are qu and the aspirates
    # ch, ph, th, which should never be separated in syllabification:
    # architectus, ar-chi-tec-tus; loquacem, lo-qua-cem.
    #
    # LRR: I'm also adding the vowels ae and oe to this list
    #
    # LRR: In effect, the "exception 2" is covered by treating these
    # digraphs as single consonants:
    # A mute consonant (b, c, d, g, p, t) or f followed by a liquid
    # consonant (l, r) go with the succeeding vowel: "la-crima", "pa-tris"
    composed = /^(qu|[cptzsgr]h|ae|oe|ck|ll|tt|[bcdgptf][lr])$/i

    while pos < word.length
      prev_consonant =
        if pos >= 2 && word[pos - 2] =~ composed
          word[pos - 2] !~ vowel
        else
          word[pos - 1] !~ vowel
        end
      prev_consonant ||= pos == 1 && word[pos - 1] == 'y'
      this_consonant = word[pos] !~ vowel
      this_consonant ||= pos == 0 && word[pos] == 'y'
      syllables[-1] += word[pos]
      if word[pos, 2] =~ composed ||
          (syllables[-1].length == 1 && word[pos, 2] =~ /^(p[st]|t[sz])$/i)
        syllables[-1] += word[pos += 1]
      end
      next_consonant = word[pos + 1] !~ vowel
      post_consonant =
        if word[pos + 1, 2] =~ composed
          word[pos + 3] !~ vowel
        else
          word[pos + 2] !~ vowel
        end

      if !this_consonant
        # 1. After open vowels (those not followed by a consonant)
        # (e.g., "pi-us" and "De-us")
        syllables << '' unless next_consonant

        # 2. After vowels followed by a single consonant
        # (e.g., "vi-ta" and "ho-ra")
        syllables << '' if next_consonant && !post_consonant

        # LRR: The following is not 
      else
        # 3. After the first consonant when two or more consonants follow a
        # vowel (e.g., "mis-sa", "minis-ter", and "san-ctus").
        syllables << '' if next_consonant && !prev_consonant
      end

      pos += 1
    end

    syllables.delete_if(&:empty?)

    # Propose emphasis
    if syllables.size == 1
      # No accent for monosyllabic words
    elsif word =~ /(aceae|ia|icus|iae|icola)$/
      syllables[-3] += "'"
    else
      syllables[-2] += "'"
    end

    # Join and return
    syllables.join('.').gsub(/'./, "'")
  end
end
