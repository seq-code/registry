module PageHelper
  def page_url(name)
    send("page_#{name}_url")
  end

  def page_path(name)
    send("page_#{name}_path")
  end

  def link_to_rule(number, text = nil)
    link_to_rule_or_recommendation('rule', number, text)
  end

  def link_to_recommendation(number, text = nil)
    link_to_rule_or_recommendation('recommendation', number, text)
  end

  def link_to_rule_or_recommendation(section, number, text = nil)
    if number =~ /^appendix-(\S+)$/
      text ||= "Appendix #{$1.upcase}"
      anchor = "appendix-#{$1}"
    else
      text ||= number
      anchor = "#{section}-#{number.to_s.gsub(/\..*/, '')}"
    end

    link_to_seqcode_section(text, anchor)
  end

  def link_to_seqcode_section(text, anchor)
    link_to(page_seqcode_path(anchor: anchor), class: 'text-info') do
      content_tag(:u, text)
    end
  end
end
