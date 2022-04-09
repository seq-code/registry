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

  def link_to_name(name)
    link_to(name.name_html, name)
  end

  def name_lineage(name)
    name.lineage.map do |name|
      link_to(name.name_html, name) + content_tag(:span, ' &raquo; '.html_safe)
    end.inject(:+) + @name.name_html
  end
end
