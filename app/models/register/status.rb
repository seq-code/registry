module Register::Status
  # ============ --- GENERIC STATUS --- ============

  attr_accessor :status_alert

  def status_name
    validated? ? 'validated' :
      notified? ? 'notified' :
      endorsed? ? 'endorsed' :
      submitted? ? 'submitted' : 'draft'
  end

  def status_help_hash
    {
      draft:
        'This is a draft register list, currently in preparation',
      submitted:
        'This register list is currently being evaluated by expert curators ' \
        'or awaiting effective publication',
      endorsed:
        'All the names in this register list have been endorsed by expert ' \
        'curators, and the SeqCode is awaiting notification of publication',
      notified:
        'The SeqCode has been notified of effective publication and the ' \
        'request is currently being evaluated by expert curators',
      validated:
        'All names in this register list have been validly published ' \
        'with a registered effective publication'
    }
  end

  def status_help
    status_help_hash[status_name.to_sym]
  end

  def in_curation?
    notified? || endorsed? || submitted?
  end

  def before_notification?
    !validated? && !notified?
  end

  def endorsed?
    submitted? && all_endorsed?
  end

  def draft?
    status_name == 'draft'
  end

  def public?
    can_view? nil
  end

  def all_endorsed?
    names.all?(&:after_endorsement?)
  end

  # ============ --- CHANGE STATUS --- ============

  ##
  # Submit the list for evaluation
  # 
  # user: The user submitting the list (the current user)
  def submit(user)
    assert_status_with_alert(draft?, 'submit') or return false
    ActiveRecord::Base.transaction do
      par = { status: 10, submitted_at: Time.now, submitted_by: user }
      names.each do |name|
        name.update!(par)
      end
      update_status_with_alert(
        submitted: true, submitted_at: Time.now,
        genomics_review: false, nomenclature_review: false
      ) or return false
    end
    notify_status_change(:submit, user)
  end

  ##
  # Return the register (and all associated names) to the authors
  #
  # user: The user returning the liat (the current user, a curator)
  # notes: Notes to add to the list, overwritting any old notes
  def return(user, notes)
    assert_status_with_alert(in_curation?, 'return') or return false
    ActiveRecord::Base.transaction do
      names.each { |name| name.update!(status: 5) unless name.validated? }
      update_status_with_alert(
        submitted: false, notified: false, notes: notes
      ) or return false
    end
    notify_status_change(:return, user)
  end

  ##
  # Endorse the register (and all associated names)
  #
  # user: The user endorsing the list (the current user, a curator)
  def endorse(user)
    ActiveRecord::Base.transaction do
      par = { status: 12, endorsed_by: user, endorsed_at: Time.now }
      names.each { |name| name.update!(par) unless name.after_endorsement? }
    end
    notify_status_change(:endorse, user)
  end

  ##
  # Notify the Registry of publication
  #
  # user: The user notifying the Registry (the current user)
  # params: The notification parameters
  # doi: DOI of the effective publication
  def notify(user, params, doi)
    publication = Publication.by_doi(doi)
    params[:publication] = publication

    if publication.new_record?
      errors.add(:doi, publication.errors[:doi].join('; '))
      return false
    end

    if !params[:publication_pdf] && !publication_pdf.attached?
      errors.add(:publication_pdf, 'cannot be empty')
      return false
    end

    ActiveRecord::Base.transaction do
      names.each do |name|
        unless name.after_endorsement?
          name.status = 10
          name.submitted_at = Time.now
          name.submitted_by = user
        end
        unless name.publications.include? publication
          name.publications << publication
        end
        name.proposed_in = publication
        name.save!
      end
      update_status_with_alert(params.merge(
        notified: true, notified_at: Time.now,
        genomics_review: false, nomenclature_review: false
      )) or return false
    end

    HeavyMethodJob.perform_later(:automated_validation, self)
    notify_status_change(:notify, user)
  end

  ##
  # Validate the register list and all associated names
  #
  # user: The user validating the list (the current user, a curator)
  def validate(user)
    ActiveRecord::Base.transaction do
      par = { validated_by: user, validated_at: Time.now }
      names.each { |name| name.update!(par.merge(status: 15)) }
      update!(par.merge(notes: nil, validated: true))
    end
    notify_status_change(:validate, user)
  end

  ##
  # Publish the register list and register it externally
  #
  # user: The user publishing the list (the current user, an editor)
  # action: The type of action to trigger on DataCite, one of: 'publish',
  #   'update', or 'none'.
  def publish(user, action)
    assert_status_with_alert(validated?, 'publish') or return false
    action = action.present? ? action.to_sym : :none

    # Generate Certificate PDF
    list_pdf = RegistersController.render(
      assigns: { register: self },
      template: 'registers/list.html.erb',
      pdf: "Register List #{acc_url}",
      header: { html: { template: 'layouts/_pdf_header' } },
      footer: { html: { template: 'layouts/_pdf_footer' } },
      page_size: 'A4'
    )

    # Register DOI
    unless action == :none
      # Connection
      datacite = Rails.configuration.datacite
      api_url  = "#{datacite[:host]}/dois"
      api_verb = 'POST'
      cred     = "#{datacite[:user]}:#{datacite[:password]}"
      cred64   = Base64.strict_encode64(cred)
      headers  = {
        'Content-Type' => 'application/vnd.api+json',
        'Authorization' => "Basic #{cred64}",
      }

      # Payload and Request
      doi = propose_doi
      cite64 = Base64.strict_encode64(RegistersController.render(
        :cite, format: 'xml', assigns: { register: self }
      ))
      attributes = { xml: cite64, url: acc_url(true) }
      if action == :publish
        attributes[:event] = 'publish'
        attributes[:doi]   = doi
      else
        api_url += '/' + doi
        api_verb = 'PUT'
        attributes[:event] = 'hide' if action == :hide
        attributes[:event] = 'publish' if action == :republish
      end
      payload = JSON.generate(data: { type: 'dois', attributes: attributes })
      uri = URI.parse(api_url)
      response = nil
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        response = http.send_request(api_verb, uri, payload, headers)
      end

      unless response.is_a? Net::HTTPSuccess
        error_type = response.class.to_s
          .sub(/^.*::(HTTP)?/, '').gsub(/([A-Z])/, ' \\1').strip
        errors = JSON.parse(response.body || '{}')['errors']
        errors &&= errors.map { |i| i['title'] }.join(', ')
        @status_alert = 'DataCite returned "%s": %s' % [error_type, errors]
        return false
      end
    end

    # Update
    update!(
      published_at: Time.now, published_doi: doi, published_by: user,
      published: true, certificate_image: list_pdf
    )

    HeavyMethodJob.perform_later(:post_publication, self)
    true
    # No notification for published lists
  end

  # ============ --- TASKS ASSOCIATED TO STATUS CHANGE --- ============

  ##
  # Production tasks to be executed once a list is published
  def post_publication
    # TODO Distribute the certificate to mirrors
  end

  ##
  # Automated checks to prepare for validation, adding relevant notes
  # to the list
  def automated_validation
    # Trivial cases (not-yet-notified or already validated)
    return false unless notified?
    return true if validated?

    # Minimum requirements
    success = true
    unless publication && publication_pdf.attached?
      add_note('Missing publication or PDF files')
      success = false
    end

    # Check that all names have been endorsed
    unless names.all?(&:after_endorsement?)
      add_note('Some names have not been endorsed yet')
      success = false
    end

    success = check_pdf_files && success
    save && success
  end

  ##
  # Check if the PDF file(s) include accession and all list names, and report
  # results as register list notes
  #
  # Returns boolean, with true indicating all checks passed and false otherwise
  #
  # IMPORTANT: Notes are soft-registered, remember to +save+ to make them
  # persistent
  def check_pdf_files
    has_acc = false
    bnames = Hash[names.map { |n| [n.base_name, false] }]
    cnames = Hash[names.map { |n| [n.base_name, n.corrigendum_from] }]
    [publication_pdf, supplementary_pdf].each do |as|
      break if has_acc && bnames.values.all?
      next unless as.attached?

      as.open do |file|
        render = PDF::Reader.new(file.path)
        render.pages.each do |page|
          txt = page.text
          has_acc = true if txt.index(accession)
          bnames.each_key do |bn|
            if txt.index(bn) || (cnames[bn] && txt.index(cnames[bn]))
              bnames[bn] = true
            end
          end
          break if has_acc && bnames.values.all?
        end
      end
    end

    if has_acc
      add_note('The effective publication includes the SeqCode accession')
    else
      add_note(
        'The effective publication does not include the accession ' \
        '(SeqCode, Rule 26, Note 2)'
      )
    end

    if bnames.values.all?
      add_note('The effective publication mentions all names in the list')
    elsif bnames.values.any?
      if bnames.values.count(&:!) > 5
        add_note(
          'The effective publication mentions' \
            " #{bnames.values.count(&:itself)} out of" \
            " #{bnames.count} names in the list"
        )
      else
        add_note(
          'The effective publication mentions some names in the list,' \
            " but not: #{bnames.select { |_, v| !v }.keys.join(', ')}"
        )
      end
    else
      add_note(
        'The effective publication does not mention any names in the list'
      )
    end

    has_acc && bnames.values.all?
  end
end
