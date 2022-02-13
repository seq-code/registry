class PageController < ApplicationController
  def publications
  end

  def seqcode
    render = SeqCodeDown.new(with_toc_data: true)
    @markdown = Redcarpet::Markdown.new(render, autolink: true, tables: true)
    @seqcode = File.read(Rails.root.join('seqcode', 'README.md'))
  end
end

class SeqCodeDown < Redcarpet::Render::HTML
end
