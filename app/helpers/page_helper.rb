module PageHelper
  def page_url(name)
    send("page_#{name}_url")
  end

  def page_path(name)
    send("page_#{name}_path")
  end

  def link_to_rule(number)
    link_to_rule_or_recommendation('rule', number)
  end

  def link_to_recommendation(number)
    link_to_rule_or_recommendation('recommendation', number)
  end

  def link_to_rule_or_recommendation(section, number)
    if number =~ /^appendix-(\S+)$/
      link_to_seqcode_section("Appendix #{$1.upcase}", "appendix-#{$1}")
    else
      link_to_seqcode_section(number, "#{section}-#{number.gsub(/\..*/, '')}")
    end
  end

  def link_to_seqcode_section(text, anchor)
    link_to(page_seqcode_path(anchor: anchor), class: 'text-info') do
      content_tag(:u, text)
    end
  end
end
