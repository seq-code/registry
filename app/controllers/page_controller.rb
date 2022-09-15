class PageController < ApplicationController
  def publications
  end

  def seqcode
    render = SeqCodeDown.new(with_toc_data: true)
    @markdown = Redcarpet::Markdown.new(render, autolink: true, tables: true)
    seqcode_path = Rails.root.join('seqcode')
    @seqcode = File.read(seqcode_path.join('README.md'))
    @tag = `cd "#{seqcode_path}" && git describe --tags --abbrev=0`.chomp
    @last_modified =
      Date.parse(`cd "#{seqcode_path}" && git log -1 --format=%cd`.chomp)
  end

  def initiative
    redirect_to 'https://www.isme-microbes.org/seqcode-initiative'
  end

  def connect
    redirect_to slack_url
  end
end

class SeqCodeDown < Redcarpet::Render::HTML
end
