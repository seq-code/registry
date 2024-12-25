module Name::Wiki
  def name_wiki(opts = {})
    y = base_name
    if opts[:link] && opts[:eol] && validated? && rank == 'genus'
      return "{{gbr|#{y}}}"
    end

    y = "[[#{y}]]" if opts[:link]
    y = "''Candidatus'' #{y}" if !opts[:no_candidatus] && candidatus?
    return "\"#{y}\"" unless validated?

    y = "''#{y}''"
    if rank == 'species' && parent&.nomenclatural_type_id&.==(id)
      y += " (T#{'s' unless icnp? || icn?})"
    end
    opts[:eol] ? "#{y} <br/>" : y
  end

  def formal_wiki
    y = name_wiki
    y += ' corrig.' if corrigendum_from?
    if not_validly_proposed_in.any?
      y += ' (ex'
      y += not_validly_proposed_in
             .map { |i| " #{sanitize(i.short_citation(:wikispecies))}" }
             .join('; ')
      y += ')'
    end
    if authority || proposed_in
      y += " #{sanitize(authority || proposed_in.short_citation(:wikispecies))}"
    end
    if priority_date && priority_date.year != proposed_in&.journal_date&.year
      y += " (valid #{priority_date.year})"
    end
    if emended_in.any?
      cit = emended_in.map { |p| p.short_citation(:wikispecies) }.join('; ')
      y += " emend. #{cit}"
    end
    sanitize(y.gsub(/{{aut\|/, '{{a|'))
  end

  def wiki_url_name
    base_name.tr(' ', '_')
  end

  def edit_wikispecies_page_link
    'https://species.wikimedia.org/w/index.php?title=%s&action=edit' %
      wiki_url_name
  end

  def edit_wikispecies_template_link
    'https://species.wikimedia.org/w/index.php?title=Template:%s&action=edit' %
      wiki_url_name
  end

  def wikispecies_url
    'https://species.wikimedia.org/wiki/%s' %
      wiki_url_name
  end

  def check_wikispecies
    issues = []
    doc = external_request(wikispecies_url)
    if !doc.present?
      issues << 'missing page'
    else
      xml = Nokogiri::HTML.parse(doc)
      if xml.xpath("//a[@href='#{seqcode_url(true)}']").empty?
        issues << "SeqCode entry not linked"
      end
      if parent && parent.validated? && parent != self
        i = parent.wiki_url_name
        unless xml.xpath("//a[@href='/wiki/#{i}']").any? ||
            xml.xpath("//a[starts-with(@href,'/w/index.php?title=#{i}&')]").any?
          issues << "parent not linked: #{parent.name}"
        end
      end
      valid_children.each do |child|
        i = child.wiki_url_name
        unless xml.xpath("//a[@href='/wiki/#{i}']").any? ||
            xml.xpath("//a[starts-with(@href,'/w/index.php?title=#{i}&')]").any?
          issues << "child not linked: #{child.name}"
        end
      end
    end
    update_columns(
      wikispecies_checked_at: DateTime.now,
      wikispecies_issues_text: issues.empty? ? nil : issues.join('; ')
    )
  end

  def wikispecies_issues
    unless wikispecies_checked_at && wikispecies_checked_at > 1.month.ago
      check_wikispecies
    end

    @wikispecies_issues ||= (wikispecies_issues_text || '').split('; ')
  end
end
