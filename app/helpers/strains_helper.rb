module StrainsHelper
  def strain_html(obj, opts = {})
    strain = nil
    name = opts[:name]
    opts[:no_title] ||= false
    parsed =
      case obj
      when Strain
        strain = obj
        obj.numbers_parsed
      when Name
        name = obj
        if obj.type_is_strain?
          strain = obj.type_strain
          strain.try(:numbers_parsed)
        else
          strain = obj.type_genome.try(:strain)
          strain.try(:numbers_parsed)
        end
      else
        obj
      end

    y = strain_numbers_html(parsed, opts)
    y = display_link(strain) + ': ' + y unless strain.nil? || opts[:no_title]
    if strain && !opts[:no_strain_info]
      y += content_tag(:span, ' ', class: 'mx-1') +
           strain_info_button(strain, name)
    end
    y
  end

  def strain_numbers_html(numbers, opts = {})
    opts[:ext] = true if opts[:ext].nil?
    ext = opts[:ext] ? '<sup class="fas fa-external-link-alt "> </sup>' : ''

    numbers.map do |str|
      if str.is_a?(StrainCode::Number) && str.url.present?
        '<a href="%s" title="%s" target="_blank">%s %s</a>' % [
          str.url, sanitize(str.catalogue&.name), sanitize(str.number), ext
        ]
      elsif str.is_a?(StrainCode::Number) && str.catalogue&.name.present?
        ('<abbr title="%s - %s">%s</abbr>' % [
          sanitize(str.catalogue.name),
          sanitize(str.accession),
          sanitize(str.number)
        ]) +
          if str.catalogue.url.present?
            ' (<a href="%s" title="catalogue" target="_blank">cat %s</a>)' % [
              str.catalogue.url, ext
            ]
          else
            ''
          end
      else
        str
      end
    end.join(' = ').html_safe
  end

  def strain_info_button(strain, name = nil, text = 'Lookup StrainInfo')
    id = modal(
      'StrainInfo data', size: 'lg',
      async: strain_info_strain_url(strain, name: name, content: true)
    )

    modal_button(id, class: 'badge badge-pill badge-info mr-2') do
      fa_icon('info-circle', class: 'mr-2') + text
    end
  end
end
