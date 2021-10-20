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

  def grammar
    etymology(:xx, :grammar)
  end

  def grammar_has?(regex)
    return nil unless grammar

    !!(grammar =~ /(^| )#{regex}( |$)/)
  end

  def adjective?
    grammar_has? /adj(\.|ective)/
  end

  def noun?
    grammar_has? /(n(\.|oun)|s(\.|ubst(\.|antive)))/
  end

  def feminine?
    grammar_has? /fem(\.|inine)/
  end

  def masculine?
    grammar_has? /masc(\.|uline)/
  end

  def neuter?
    grammar_has? /neut(\.|er)/
  end

  def plural?
    grammar_has? /pl(\.|ural)/
  end

  def language
    etymology(:xx, :language)
  end
end
