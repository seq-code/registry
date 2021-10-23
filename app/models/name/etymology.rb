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
    @importable_etymology ||=
      Name.where('name LIKE ?', "% #{last_epithet}")
          .where.not(etymology_xx_grammar: [nil, ''])
          .last
  end

  ##
  # Can the etymology be automatically filled on the basis of the type genus?
  def can_autofill_etymology?
    return true if rank? && type_is_name? && type_name.rank == 'genus'
    !importable_etymology.nil?
  end

  ##
  # Attempt automatically fill the etymology on the basis of the type genus. It
  # affects the current instance but does not save changes to the database!
  def autofill_etymology
    return unless can_autofill_etymology?

    clean_etymology
    if type_name.rank == 'genus'
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
      self.class.etymology_particles.any? do |i|
        self.class.etymology_fields.any? do |j|
          next if i == :xx && j == :particle

          acc = "etymology_#{i}_#{j}"
          self.send("#{acc}=", importable_etymology.send(acc))
        end
      end
    end
  end
end
