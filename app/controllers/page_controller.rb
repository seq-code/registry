class PageController < ApplicationController
  def publications
  end

  def about
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
    # Generated June 15 2022 (never expires)
    redirect_to 'https://join.slack.com/t/seqcode-public/shared_invite/zt-19rqshbvn-9Rti7Tn2_CskNCkW1WIaOw'
  end

  def join
    # Generated September 15 2022 (Google form)
    redirect_to 'https://forms.gle/ZJQVu3XqZwBp4jb4A'
  end
end

class SeqCodeDown < Redcarpet::Render::HTML
end
