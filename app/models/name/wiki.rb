module Name::Wiki
  def name_wiki(opts = {})
    y = base_name
    if opts[:link] && opts[:eol] && validated? && rank == 'genus'
      return "{{gbr|#{y}}}"
    end

    y = "[[#{y}]]" if opts[:link]
    y = "''Candidatus'' #{y}" if !opts[:no_candidatus] && candidatus?

    if validated?
      y = "''#{y}''"
      if rank == 'species' && parent&.nomenclatural_type_id&.==(id)
        y += " (T#{'s' unless icnp? || icn?})"
      end
    else
      y = "\"#{y}\""
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

  def wikispecies_url_name
    wikispecies_entry.present? ? wikispecies_entry.tr(' ', '_') : wiki_url_name
  end

  def edit_wikispecies_page_link
    'https://species.wikimedia.org/w/index.php?title=%s&action=edit' %
      wikispecies_url_name
  end

  def edit_wikispecies_template_link
    'https://species.wikimedia.org/w/index.php?title=Template:%s&action=edit' %
      wikispecies_url_name
  end

  def wikispecies_url
    'https://species.wikimedia.org/wiki/%s' % wikispecies_url_name
  end

  def wikispecies_template_url
    'https://species.wikimedia.org/wiki/Template:%s' % wikispecies_url_name
  end

  def wikispecies_needs_template?
    at_or_above_rank? :genus
  end

  def check_wikispecies
    issues = []
    doc = external_request(wikispecies_url)
    if !doc.present?
      issues << 'missing page'
    else
      xml = Nokogiri::HTML.parse(doc)
      if xml.xpath("//a[@href='#{seqcode_url(true)}']").empty?
        issues << 'SeqCode entry not linked'
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
          issues <<
            "child not linked: #{child.name}#{' (SeqCode)' if child.seqcode?}"
        end
      end
    end

    if wikispecies_needs_template?
      unless external_request(wikispecies_template_url).present?
        issues << 'missing template'
      end
    end

    update_columns(
      wikispecies_checked_at: DateTime.now,
      wikispecies_issues_text: issues.empty? ? nil : issues.join('; ')
    )
  end

  def wikispecies_issues(force: false)
    if force ||
          !wikispecies_checked_at.present? ||
          wikispecies_checked_at < 1.month.ago
      check_wikispecies
    end

    (wikispecies_issues_text || '').split('; ')
  end

  def wikispecies_page_exists?
    !wikispecies_issues.include?('missing page')
  end

  def wikispecies_template_exists?
    !wikispecies_issues.include?('missing template')
  end

  # Rendered from the exact same partials used on the manual "Wiki code" page,
  # so submission always matches what a curator would see and copy by hand.
  def wikispecies_page_wikitext
    CGI.unescapeHTML(
      ApplicationController.renderer.render(
        partial: 'names/wiki/wikispecies_page', assigns: { name: self }
      )
    )
  end

  def wikispecies_template_wikitext
    CGI.unescapeHTML(
      ApplicationController.renderer.render(
        partial: 'names/wiki/wikispecies_template', assigns: { name: self }
      )
    )
  end

  ##
  # Creates the Wikispecies template (if needed) and page for this name,
  # using the passed Wikispecies::Client (already authenticated as a user
  # or bot). Returns a symbol describing what happened, and never
  # overwrites an existing page (create-only semantics enforced both here
  # and, redundantly, in the client itself).
  def submit_to_wikispecies!(client)
    # Non-validated names are sometimes needed. e.g., as ancestors
    # return :not_validated unless validated?
    action = :page_exists

    if parent.present? && parent.submit_to_wikispecies!(client) != :page_exists
      action = :parent_created
    end

    if wikispecies_needs_template? && !wikispecies_template_exists?
      client.create_page(
        title: "Template:#{wikispecies_url_name}",
        content: wikispecies_template_wikitext,
        summary:
          "Creating taxonavigation template " \
          "per SeqCode Registry #{register&.acc_url}"
      )
      action = :template_created
    end

    unless wikispecies_page_exists?
      client.create_page(
        title: wikispecies_url_name,
        content: wikispecies_page_wikitext,
        summary: "Creating page per SeqCode Registry #{register&.acc_url}"
      )
      action = :created
    end

    check_wikispecies unless action == :page_exists
    action
  rescue WikispeciesClientService::Error => e
    Rails.logger.error(
      "Wikispecies submission failed for #{name}: #{e.message}"
    )
    :error
  end
end

