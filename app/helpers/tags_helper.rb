module TagsHelper
  # Badge colored with the tag's own color, with a readable foreground
  def tag_badge(tag, link: true, faded: false)
    bg = tag.color.presence || '#6c757d'
    style = "background-color: #{bg}; color: #{tag_text_color(bg)};"
    style += ' opacity: 0.5;' if faded
    opts = { class: 'badge badge-pill', style: style, title: tag_title(tag) }
    if link
      link_to(tag.name, tag_path(tag), opts)
    else
      content_tag(:span, tag.name, opts)
    end
  end

  # Plain-text description of the tag (for hover titles), or its slug if it
  # has no description
  def tag_title(tag)
    tag.description.to_plain_text.squish.presence || tag.slug
  end

  # Black or white text depending on the luminance of a hex color
  def tag_text_color(hex)
    rgb = hex.to_s.delete('#')
    return '#fff' unless rgb =~ /\A\h{6}\z/

    r, g, b = rgb.scan(/../).map { |i| i.to_i(16) }
    (0.299 * r + 0.587 * g + 0.114 * b) > 150 ? '#212529' : '#fff'
  end

  # Grouped options for tag selects: one group per umbrella tag (the umbrella
  # itself followed by its sub-tags), plus a final group of standalone tags
  def tag_grouped_options(except: [])
    tops = Tag.top_level.includes(:children).order(:name)
    umbrellas, standalone = tops.partition { |t| t.children.any? }
    opt = ->(list) { (list - except).map { |t| [t.name, t.id] } }
    groups = umbrellas.map do |top|
      [top.name, opt[[top] + top.children.sort_by(&:name)]]
    end
    groups << ['Other', opt[standalone]] if standalone.any?
    groups.reject { |_, list| list.empty? }
  end
end
