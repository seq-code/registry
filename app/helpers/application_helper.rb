module ApplicationHelper
  def list_preference
    cookies[:list] || 'cards'
  end

  def pager(object)
    will_paginate object,
      renderer: WillPaginate::ActionView::BootstrapLinkRenderer,
      list_classes: %w(pagination justify-content-center)
  end

  def current_contributor?
    current_user.try :contributor?
  end

  def current_curator?
    current_user.try :curator?
  end

  def current_admin?
    current_user.try :admin?
  end

  def adaptable_list(opts = {}, &blk)
    opts[:type] ||= list_preference.to_sym
    list = AdaptableList.new(opts)
    o = []
    o << pager(list.set) if list.set
    o << content_tag(list.tag, list.css) do
      if list.type == :cards
        blk[list]
      else
        body = content_tag(:tbody) { blk[list] }
        content_tag(:thead) do
          content_tag(:tr) do
            ([nil] + list.value_names)
              .map { |i| content_tag(:th, i, scope: :col) }
              .compact
              .inject(:+)
          end
        end + body
      end
    end
    o << pager(list.set) if list.set
    o << tag(:br)
    o.compact.inject(:+)
  end

  def adaptable_entry(list, title, link)
    entry = list.entry
    content_tag(entry.tag, entry.css) do
      o = []
      if list.type == :cards
        o << link_to(link, entry.link_css) do
          content_tag(entry.header_tag, entry.header_css) do
            content_tag(:h3, title)
          end
        end
        o << content_tag(entry.content_tag, entry.content_css) do
          content_tag(:dl) { yield(entry) }
        end
        if entry.footer_blk
          o << content_tag(entry.footer_tag, entry.footer_css) do
            entry.footer_blk.call
          end
        end
      else
        o << content_tag(entry.header_tag, entry.header_css, scope: :row) do
          link_to(title, link, entry.link_css)
        end
        o << content_tag(:div) { yield(entry) }
        if entry.footer_blk
          o << content_tag(entry.footer_tag, entry.footer_css) do
            entry.footer_blk.call
          end
        end
      end
      o.compact.inject(:+)
    end
  end

  def adaptable_value(entry, name)
    value = entry.value(name)
    o = []
    o << content_tag(:dt, name) if value.type == :cards
    o << content_tag(value.tag) { yield(value) }
    o.compact.inject(:+)
  end
end

class AdaptableList
  attr :type, :set, :value_names

  def initialize(opts)
    @type = opts[:type]
    @set  = opts[:set]
    @value_names = []
  end

  def css
    { cards: { class: 'card-columns' }, table: { class: 'table table-hover' } }[type]
  end

  def tag
    { cards: :div, table: :table }[type]
  end

  def entry
    AdaptableListEntry.new(self)
  end

  def add_value_name(name)
    @value_names << name unless value_names.include? name
  end
end

class AdaptableListEntry
  attr :list, :footer_blk, :values

  def initialize(list)
    @list       = list
    @footer_blk = nil
    @values     = []
  end

  def type
    list.type
  end

  def css
    { cards: { class: 'card' }, table: {} }[type]
  end

  def tag
    { cards: :div, table: :tr }[type]
  end

  def link_css
    { cards: { class: 'card-header-link' }, table: {} }[type]
  end

  def header_tag
    { cards: :div, table: :th }[type]
  end

  def header_css
    { cards: { class: 'card-header'}, table: {} }[type]
  end

  def content_tag
    { cards: :div, table: nil }[type]
  end

  def content_css
    { cards: { class: 'card-body' }, table: nil }[type]
  end

  def footer(&blk)
    list.add_value_name(nil)
    @footer_blk = blk
  end

  def footer_tag
    { cards: :div, table: :td }[type]
  end

  def footer_css
    { cards: { class: 'card-footer text-right bg-dark-ce' }, table: {} }[type]
  end

  def value(name)
    list.add_value_name(name)
    AdaptableListValue.new(self)
  end
end

class AdaptableListValue
  attr :entry

  def initialize(entry)
    @entry = entry
  end

  def list
    entry.list
  end

  def type
    entry.list.type
  end

  def tag
    { cards: :dd, table: :td }[type]
  end
end

