module PageHelper
  def page_url(name)
    send("page_#{name}_url")
  end

  def page_path(name)
    send("page_#{name}_path")
  end

  def link_to_rule(number)
    link_to_seqcode_section(number, "rule-#{number.gsub(/\..*/, '')}")
  end

  def link_to_recommendation(number)
    link_to_seqcode_section(number, "recommendation-#{number.gsub(/\..*/, '')}")
  end

  def link_to_seqcode_section(text, anchor)
    link_to(page_seqcode_path(anchor: anchor), class: 'text-info') do
      content_tag(:u, text)
    end
  end
end
