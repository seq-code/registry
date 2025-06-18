class PageController < ApplicationController
  # GET /page/publications
  def publications
  end

  # GET /page/about
  def about
  end

  # GET /page/status
  # GET /page/status.json
  def status
    respond_to do |format|
      format.html do
        redirect_to 'https://stats.uptimerobot.com/OcQhKQJ19N'
      end
      format.json
    end
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
    @crumbs = ['Help']
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

    @category = category.to_s.capitalize
    render    = SeqCodeDown.new
    @topic    = help_topics[category][topic]
    @markdown = Redcarpet::Markdown.new(render, autolink: true, tables: true)
    docs_path = Rails.root.join('documentation')
    file_path = docs_path.join(category.to_s, '%s.md' % topic)
    @document = File.read(file_path)
    @crumbs = [['Help', help_index_path], @category, @topic]

    render('help', layout: !params[:content].present?)
  end

  # GET /api
  def api
  end

  # GET /page/linkout.xml
  def linkout
    @provider_id = Rails.configuration.try(:linkout_provider_id)
    unless @provider_id.present?
      @provider_id = 'Define using config.linkout_provider_id'
    end
  end

  # GET /page/sandbox
  def sandbox
    redirect_to(etymology_sandbox_names_path)
  end

  # GET /page/stats
  def stats
    @stats = {}
    Name.ranks.each do |rank|
      @stats[rank] = Hash[
        [15, 20, 25, 0].map do |k|
          [Name.status_hash[k][:name], Name.where(status: k, rank: rank).count]
        end
      ]
    end
  end

  private

    def help_topics
      {
        tutorial: {
          new_genome: 'I have a genome belonging to a novel taxon, how can I ' \
                      'register it?'
        },
        guide: {
          etymology: 'How do I fill the etymology table?',
          dictionary: 'How do I use dictionary lookups?',
          exceptions: 'When and how do I request a genome quality exception?',
          # SOPs
          curation: 'How are names internally curated?'
        },
        explanation: {
          register: 'What are Register Lists?',
          open_data: 'What data is publicly released and how?',
          paths: 'What are the paths to validation?'
        }
      }
    end

    def help_topic_categories
      Hash[
        *help_topics.map { |k, v| v.keys.map { |topic| [topic, k] } }.flatten
      ]
    end
end

class SeqCodeDown < Redcarpet::Render::HTML
end
