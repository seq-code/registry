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

  def name_of_seqcode_section(section, number)
    number = number.gsub(/-/, ' ').titleize

    if section.to_s == 'rule_note'
      "Rule #{number} (Note)"
    else
      "#{section.capitalize} #{number}"
    end
  end

  def anchor_to_seqcode_section(section, number)
    section = 'rule' if section.to_s == 'rule_note'

    if number =~ /^appendix-(\S+)$/
      "appendix-#{$1}"
    else
      "#{section}-#{number.to_s.gsub(/\..*/, '')}"
    end
  end

  def link_to_rule_or_recommendation(section, number, text = nil)
    anchor = anchor_to_seqcode_section(section, number)
    text ||= name_of_seqcode_section(section, number)
    link_to_seqcode_section(text, anchor)
  end

  def link_to_seqcode_section(text, anchor)
    link_to(page_seqcode_path(anchor: anchor)) do
      content_tag(:u, text)
    end
  end

  def seqcode_excerpt(section, number)
    unless @sq_noko
      @sq_down  ||= Redcarpet::Render::HTML.new(with_toc_data: true)
      @markdown ||= Redcarpet::Markdown.new(@sq_down, autolink: true, tables: true)
      @seqcode  ||= @markdown.render(File.read(Rails.root.join('seqcode', 'README.md')))
      @sq_noko = Nokogiri::HTML(@seqcode)
      # Fix in-page links
      @sq_noko.xpath("//*[contains(@href, '#')]").each do |i|
        i[:href] = "#{page_seqcode_path}#{i[:href]}" if i[:href] =~ /^#/
        i[:target] = '_blank'
      end
    end
    
    id = anchor_to_seqcode_section(section, number)
    xp = "*[@id='#{id}']"

    content =
      @sq_noko.xpath("//#{xp}/following-sibling::*").take_while { |i| !i['id'] }

    if number =~ /\.(\d+)/
      k = $1.to_i
      content = content.map do |i|
        i.dup.tap { |y| y.xpath("li[#{k}]").set(:class, 'highlight') }
      end
    end

    if section =~ /_note$/
      content = content.map do |i|
        i.dup.tap do |y|
          y.xpath("strong[contains(text(), 'Note')]/..")
           .set(:class, 'highlight')
        end
      end
    end

    @sq_noko.xpath("//#{xp}[1]").to_s.html_safe +
      content.map(&:to_s).join.html_safe
  end

  def link_to_seqcode_excerpt(section, number, text = nil)
    anchor = anchor_to_seqcode_section(section, number)
    text ||= name_of_seqcode_section(section, number)

    id = modal('SeqCode Excerpt', size: 'lg') do
      content_tag(:div, seqcode_excerpt(section, number), class: 'px-4 py-2') +
        content_tag(:hr) +
        fa_icon('hand-point-right', class: 'ml-4 mr-2') +
        link_to('See in context',
          page_seqcode_path(anchor: anchor), target: '_blank')
    end

    modal_button(id, class: '', type: '', tag: :a, href: '#') do
      content_tag(:u, text)
    end
  end
end
