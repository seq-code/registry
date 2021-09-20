module NamesHelper
  def link_to_name_type(name)
    if name.type_is_name?
      if name.type_name
        link_to(name.type_name) { name.type_name.name_html }
      else
        content_tag(:span, "Illegal name: #{name.type_accession}", class: 'text-danger')
      end
    elsif name.type_link
      link_to(name.type_link, target: '_blank') do
        content_tag(:span, name.type_text) +
          fa_icon('external-link-alt', class: 'ml-1')
      end
    else
      name.type_text
    end
  end
end
