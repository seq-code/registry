module ApplicationHelper
  def show_tax_string(string, opts = {})
    opts[:class] ||= 'tax-string'
    content_tag(:span, opts) do
      string = string.split(/ (>|&raquo;|\/) /) unless string.is_a?(Array)
      string.each_with_index.map do |i, k|
        r, n  = i.split(':', 2)
        r_key = r.to_s[0].to_sym

        content_tag(:span, k == 0 ? '' : ' &raquo; '.html_safe) +
        content_tag(
          :span, n, title: Name.rank_keys[r_key],
          data: { kind: :taxonomy, rank: r_key, value: n }
        )
      end.inject(:+)
    end
  end

  def canonical_url(opts = {})
    # Clean-up options 
    opts_parse = {}
    opts.keys.map(&:to_s).sort.each do |k_s|
      k = k_s.to_sym
      next if k_s == 'page' and opts[k] == 1
      opts_parse[k] = opts[k]
    end

    url_for({
      only_path: false, protocol: 'https', host: 'registry.seqco.de'
    }.merge(opts_parse))
  end

  def report_history(obj, text: 'Report history')
    id = modal(
      'Report history', size: :xl,
      async: polymorphic_url([:reports, obj], content: true)
    )
    modal_button(id, class: 'btn btn-primary btn-sm') do
      fa_icon('archive') + ' ' + text
    end
  end

  def list_preference
    cookies[:list] || 'cards'
  end

  def download_link(file, name = nil)
    path = "#{root_url}/files/#{file}"
    local_path = File.join(Rails.public_path, 'files', file)
    name ||= File.basename(file).gsub(/\..*/, '').gsub(/_/, ' ').gsub(/-/, ', ')
    text = name + ' (' + File.extname(file).delete('.').upcase + ', ' +
           number_to_human_size(File.size(local_path)) + ')'
    link_to(path) do
      fa_icon(:download, class: 'mr-2') + content_tag(:span, text)
    end
  end

  def time_ago_with_date(date, capitalize = false)
    date  = DateTime.parse(date) if date.is_a?(String)
    fdate = date.strftime('%F %I:%M %p (%Z)')
    content_tag(:u, class: 'hover-help', title: fdate) do
      s = time_ago_in_words(date) + ' ago'
      s[0] = s[0].upcase if capitalize
      s
    end
  end

  def pager(object)
    will_paginate(
      object,
      renderer: WillPaginate::ActionView::BootstrapLinkRenderer,
      list_classes: %w(pagination justify-content-center)
    )
  end

  def full_title(page_title = '')
    (page_title.to_s + ' | ' if page_title.present?).to_s + 'SeqCode Registry'
  end

  def list_type_selector
    link_to(set_list_url(from: request.filtered_path)) do
      if list_preference.to_s == 'table'
        content_tag(:span, 'See as cards ') +
          fa_icon('th')
      else
        content_tag(:span, 'See as table ') +
          fa_icon('list')
      end
    end
  end

  def longer_list(title = '', hide_over = 3, elements = nil, &blk)
    content_tag(:div) { elements = blk.call } if block_given?
    content_tag(:ul, class: 'mb-1') do
      if hide_over && elements.count > hide_over
        id = modal(title) { longer_list('', nil, elements) }
        content_tag(:li) { elements[0] } +
        content_tag(:li) do
          modal_button(id, as_anchor: true) do
            "And #{elements.count - 1} more&hellip;".html_safe
          end
        end
      else
        elements.each_with_index.map do |content, k|
          content_tag(:li) { content }
        end.inject(:+)
      end
    end
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

  def current_editor?
    current_user.try :editor?
  end

  def current_user?(user)
    current_user && current_user == user
  end

  def adaptable_list(opts = {}, &blk)
    opts[:type] ||= list_preference.to_sym
    list = AdaptableList.new(opts)
    if list.type == :single_card
      list.type = :cards
      return blk[list]
    end

    o = []
    o << pager(list.set) if list.set
    o << content_tag(list.tag, list.css) do
      if list.type == :cards
        blk[list]
      else
        body = content_tag(:tbody) { blk[list] }
        content_tag(:thead) do
          opts[:noheader] ? nil :
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

  def adaptable_entry(list, title, link, opts = {})
    entry = list.entry
    container_opts = entry.css.merge(opts[:container_opts] ||= {})
    if opts[:full_link]
      container_opts.tap do |o|
        o[:class] ||= ''
        o[:class]  += ' ' + opts[:class] if opts[:class]
        o[:class]  += ' clickeable'
        o[:data]  ||= {}
        o[:data][:href] = polymorphic_url(link)
        o[:onclick] = 'location.href=$(this).data("href");'
      end
    end

    content_tag(opts[:container_tag] || entry.tag, container_opts) do
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
        end unless list.opts[:nolead]
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

  def adaptable_value(entry, name, opts = {})
    value = entry.value(name)
    o = []
    value_class = opts[:class] || ''
    o << content_tag(:dt, name) if value.type == :cards
    o << content_tag(value.tag, class: value_class) do
           yield(value)
         end
    o.compact.inject(:+)
  end

  def modal(title, opts = {})
    @modals ||= []
    id = opts[:id] || "modal-#{SecureRandom.uuid}"
    if opts[:async]
      opts[:container_data] ||= {}
      opts[:container_data][:async] = opts[:async]
    end
    opts[:body_class] ||= ''
    opts[:body_class] += ' modal-body'
    @modals <<
      content_tag(
        :div, id: id, class: 'modal fade', tabindex: '-1', role: 'dialog',
        data: opts[:container_data]
      ) do
        dialog_class = 'modal-dialog modal-dialog-centered'
        dialog_class += " modal-#{opts[:size]}" if opts[:size]
        content_tag(:div, class: dialog_class, role: 'document') do
          content_tag(:div, class: 'modal-content') do
            content_tag(:div, class: 'modal-header') do
              content_tag(:h5, title, class: 'modal-title') +
                content_tag(
                  :button, type: 'button', class: 'close',
                  data: { dismiss: 'modal' },
                  aria: { label: 'Close' }
                ) do
                  content_tag(
                    :span, '&times;'.html_safe, aria: { hidden: true }
                  )
                end
            end +
            content_tag(:div, class: opts[:body_class]) do
              yield if block_given?
            end +
            if opts[:footer]
              content_tag(:div, opts[:footer], class: 'modal-footer')
            end
          end
        end
      end
    return id
  end

  def modal_button(id, opts = {})
    opts[:type] ||= 'button'
    opts[:class] ||= 'btn btn-primary'
    opts[:data] ||= {}
    opts[:data][:toggle] = 'modal'
    opts[:data][:target] = "##{id}"
    opts[:tag] ||= :span
    opts.merge!(type: '', class: '', tag: :a, href: '#') if opts[:as_anchor]
    content_tag(opts.delete(:tag), opts) { yield }
  end

  def help_message(title = '', opts = {})
    id = modal(title) { yield }
    help_button(id, opts)
  end

  def help_button(id, opts = {})
    opts[:class] ||= ''
    opts[:icon]  ||= 'question-circle'
    modal_button(id, opts) do
      content_tag(:b, opts[:text], class: 'text-info') +
      fa_icon(opts[:icon], class: 'hover-help')
    end
  end

  def help_topic(topic, title = '', opts = {})
    footer = link_to(
      'View help message as individual page', help_url(topic),
      class: 'btn btn-light w-100 m-0 p-2'
    )
    new_opts = opts.merge(
      footer: footer, async: help_url(topic, content: true), body_class: 'm-3'
    )
    id = modal(title, new_opts)
    if opts[:as_help]
      help_button(id, opts)
    else
      modal_button(id, class: 'btn btn-info') do
        fa_icon('question-circle', class: 'mr-2') + title
      end
    end
  end

  def yield_modals
    @modals ||= []
    @modals.inject(:+)
  end

  def download_buttons(list)
    content_tag(:div, class: 'float-right text-right') do
      list.map { |i| download_button(*i) }.inject(:+) +
        (content_tag(:span) { yield } if block_given?)
    end
  end

  def download_button(url, icon, text, opts = {})
    opts[:color] ||= 'light'
    opts[:class] ||= ''
    opts[:class]  += " btn btn-#{opts[:color]} btn-sm"
    opts[:class]  += ' text-muted' if opts[:color] == 'light'
    link_to(url, opts) do
      fa_icon(icon) + text
    end
  end

  def display_obj(obj, display_method = nil)
    preferred_fields =
      display_method ? [display_method] :
      %i[name_html name display_name accession citation full_name title]

    field = preferred_fields.find { |i| obj.respond_to? i }
    if field
      obj.send(field)
    elsif obj.respond_to? :id
      '%s %i' % [obj.class, obj.id]
    else
      obj.to_s
    end
  end

  def display_link(obj, display_method = nil, display_text: nil)
    if obj.is_a?(Name) && obj.redirect.present?
      link_to(
        display_text || display_obj(obj, display_method),
        name_url(obj, no_redirect: true)
      ) + ' ' +
        link_to(obj.redirect, class: 'badge badge-pill badge-danger') do
          fa_icon(:directions, title: 'Redirects to') + ' ' +
          display_obj(obj.redirect, display_method)
        end
    else
      link_to(display_text || display_obj(obj, display_method), obj)
    end
  end
end

class AdaptableList
  attr_accessor :type, :set, :value_names, :opts

  def initialize(opts)
    @opts = opts
    @type = opts[:type]
    @set  = opts[:set]
    @value_names = []
  end

  def css
    {
      cards: { class: 'card-columns' },
      table: { class: 'table table-hover table-responsive-md' }
    }[type]
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
