class PageController < ApplicationController
  # GET /page/publications
  def publications
  end

  # GET /page/about
  def about
  end

  # GET /page/seqcode
  def seqcode
    render = SeqCodeDown.new(with_toc_data: true)
    @markdown = Redcarpet::Markdown.new(render, autolink: true, tables: true)
    seqcode_path = Rails.root.join('seqcode')
    @seqcode = File.read(seqcode_path.join('README.md'))
    @tag = `cd "#{seqcode_path}" && git describe --tags --abbrev=0`.chomp
    @last_modified =
      Date.parse(`cd "#{seqcode_path}" && git log -1 --format=%cd`.chomp)
  end

  # GET /page/initiative
  def initiative
    redirect_to 'https://www.isme-microbes.org/seqcode-initiative'
  end

  # GET /page/connect
  def connect
    # Generated June 15 2022 (never expires)
    redirect_to 'https://join.slack.com/t/seqcode-public/shared_invite/' \
                'zt-19rqshbvn-9Rti7Tn2_CskNCkW1WIaOw'
  end

  # GET /page/join
  def join
    # Generated September 15 2022 (Google form)
    redirect_to 'https://forms.gle/ZJQVu3XqZwBp4jb4A'
  end

  # GET /page/committee
  def committee
  end

  # GET /page/prize
  def prize
  end

  # GET /help
  def help_index
    @topics = help_topics
  end

  # GET /help/topic
  def help(topic = nil)
    topic ||= params[:topic]
    topic = topic.gsub(/[^A-Za-z0-9_]/, '').to_sym
    category = help_topic_categories[topic]
    unless category
      flash[:danger] = 'Documentation topic not found'
      redirect_to(root_path)
      return
    end

    render    = SeqCodeDown.new
    @topic    = help_topics[category][topic]
    @markdown = Redcarpet::Markdown.new(render, autolink: true, tables: true)
    docs_path = Rails.root.join('documentation')
    file_path = docs_path.join(category.to_s, '%s.md' % topic)
    @document = File.read(file_path)

    render('help', layout: !params[:content].present?)
  end

  private

    def help_topics
      {
        guide: {
          etymology: 'How do I Fill the Etymology Table?'
        },
        explanation: {
          register: 'What are Register Lists?'
        },
        sop: {
          curation: 'How are names internally curated?'
        }
      }
    end

    def help_topic_categories
      Hash[help_topics.map { |k, v| v.keys.map { |topic| [topic, k] }.flatten }]
    end
end

class SeqCodeDown < Redcarpet::Render::HTML
end
