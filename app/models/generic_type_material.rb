class GenericTypeMaterial < ApplicationRecord
  include TypeMaterial

  validates(:text, presence: true)

  def type_of_type
    'Other'
  end

  def display(_html = true)
    "#{type_of_type}: #{text}"
  end

  def old_type_definition
    ['other', text]
  end

  def title(prefix = nil, html: true, sup: true)
    prefix ||= 'Material '
    y = '%ssc|%07i' % [prefix, id]
    if sup && (label = title_superscript)
      y += html ? " <sup>#{label}</sup>".html_safe : " (#{label})"
    end
    return html ? y.html_safe : y
  end
end
