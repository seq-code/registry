module StrainsHelper
  def strain_html(obj, opts = {})
    strain = nil
    name = nil
    parsed =
      case obj
      when Strain
        strain = obj
        obj.numbers_parsed
      when Name
        name = obj
        if obj.type_is_strain?
          strain = obj.type_strain
          obj.type_strain_parsed
        else
          obj.genome_strain_parsed
        end
      else
        obj
      end

    y = strain_numbers_html(parsed, opts)
    y += strain_info_button(strain, name) if strain && !opts[:no_strain_info]
    y
  end

  def strain_numbers_html(numbers, opts = {})
    opts[:ext] = true if opts[:ext].nil?
    ext = opts[:ext] ? '<sup class="fas fa-external-link-alt "> </sup>' : ''

    numbers.map do |str|
      if str.is_a? Hash
        '<a href="%s" target="_blank">%s %s</a>' % [
          str[:url], sanitize(str[:accession]), ext
        ]
      else
        str
      end
    end.join(' = ').html_safe
  end

  def strain_info_button(strain, name = nil)
    id = modal(
      'StrainInfo data', size: 'lg',
      async: strain_info_strain_url(strain, name: name, content: true)
    )

    modal_button(id, class: 'badge badge-pill badge-info mx-2') do
      fa_icon('info-circle', class: 'mr-2') + 'StrainInfo data'
    end
  end
end
