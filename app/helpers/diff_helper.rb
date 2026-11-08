module DiffHelper
  # Return each side as escaped text with changed chunks marked up.
  def text_diff(before, after)
    chunks = TextDiff.chunks(before, after)
    [[:del, 'text-danger'], [:ins, 'text-success']].each_with_index.map do |(tag, css_class), side|
      parts = chunks.filter_map do |unchanged, *texts|
        text = texts[side]
        next if text.empty?

        unchanged ? text : content_tag(tag, text, class: css_class)
      end
      safe_join(parts)
    end
  end

  # Preserve rich text formatting, allowing the diff's ins and del tags too.
  def html_diff(before, after)
    HtmlDiff.diff(before, after).map do |html|
      sanitize(
        html,
        tags: ActionText::ContentHelper.allowed_tags + %w[ins del],
        attributes: ActionText::ContentHelper.allowed_attributes
      )
    end
  end
end
