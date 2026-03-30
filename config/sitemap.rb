SitemapGenerator::Sitemap.default_host  = 'https://registry.seqco.de'
SitemapGenerator::Sitemap.sitemaps_path = '/'

SitemapGenerator::Sitemap.create do

  # Global index
  # %w[pages names genomes strains registers].each do |base|
  #   add_to_index 'sitemaps/%s.xml.gz' % base
  # end

  # Top-level pages
  group(filename: :pages, sitemaps_path: 'sitemaps/') do
    extend HelpTopics

    add root_path, changefreq: :daily, priority: 1.0

    # Pages
    add page_api_path, changefreq: :monthly, priority: 0.4
    add page_about_path, changefreq: :weekly, priority: 0.8
    add page_committee_path, changefreq: :monthly, priority: 0.6
    add page_news_path, changefreq: :monthly, priority: 0.6
    add page_prize_path, changefreq: :monthly, priority: 0.4
    add page_publications_path, changefreq: :monthly, priority: 0.4
    add page_seqcode_path, changefreq: :monthly, priority: 0.8

    # Help
    add help_index_path, changefreq: :weekly, priority: 0.8
    help_topics.each do |_cat, topics|
      topics.each do |topic, _data|
        add help_path(topic: topic), changefreq: :monthly, priority: 0.8
      end
    end

    # User registration
    add '/sign_up', changefreq: :monthly, priority: 0.5
    add '/login', changefreq: :monthly, priority: 0.5

    # Indexes
    add name_type_genomes_path, changefreq: :weekly, priority: 0.6
    add names_path, changefreq: :daily, priority: 0.8
    add submitted_names_path, changefreq: :daily, priority: 0.8
    add endorsed_names_path, changefreq: :daily, priority: 0.8
    add strains_path, changefreq: :daily, priority: 0.6
    add registers_path, changefreq: :weekly, priority: 0.8
    add authors_path, changefreq: :daily, priority: 0.4
    add journals_path, changefreq: :monthly, priority: 0.4
    add publications_path, changefreq: :daily, priority: 0.4
    add subjects_path, changefreq: :monthly, priority: 0.2
    add search_path, changefreq: :monthly, priority: 0.2
  end

  # Names
  group(filename: :names, sitemaps_path: 'sitemaps/') do
    Name.all_public.find_each do |name|
      add name_path(name), lastmod: name.updated_at,
          changefreq: :weekly, priority: 0.6
      add wiki_name_path(name), lastmod: name.updated_at,
          changefreq: :weekly, priority: 0.1
      # TODO:
      # - add network
    end
  end

  # Genomes
  group(filename: :genomes, sitemaps_path: 'sitemaps/') do
    Genome.all_public.find_each do |genome|
      add genome_path(genome), lastmod: genome.updated_at,
          changefreq: :weekly, priority: 0.4
      # TODO:
      # - add sample_map
    end
  end

  # Strains
  group(filename: :strains, sitemaps_path: 'sitemaps/') do
    Strain.find_each do |strain|
      add strain_path(strain), lastmod: strain.updated_at,
          changefreq: :weekly, priority: 0.4
    end
  end

  # Registers
  group(filename: :registers, sitemaps_path: 'sitemaps/') do
    Register.where(validated: true).find_each do |register|
      add register_path(register), lastmod: register.updated_at,
          changefreq: :weekly, priority: 0.6
      # TODO:
      # - add table
      # - add list
      # - add sample_map
      # - add tree
    end
  end

  # TODO Add members for:
  # - authors
  # - journals
  # - publications
  # - subjects

end

