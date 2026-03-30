SitemapGenerator::Sitemap.default_host  = 'https://registry.seqco.de'
SitemapGenerator::Sitemap.sitemaps_path = 'sitemaps/'
SitemapGenerator::Sitemap.sitemaps_host = '%s/%s' % [
  SitemapGenerator::Sitemap.default_host,
  SitemapGenerator::Sitemap.sitemaps_path
]

# Global index
SitemapGenerator::Sitemap.adapter       = SitemapGenerator::FileAdapter.new
SitemapGenerator::Sitemap.filename      = 'sitemap.xml'
SitemapGenerator::Sitemap.create_index  = true

# Top-level pages
SitemapGenerator::Sitemap.namer = SitemapGenerator::SimpleNamer.new(:pages)
SitemapGenerator::Sitemap.create do
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
SitemapGenerator::Sitemap.namer = SitemapGenerator::SimpleNamer.new(:names)
SitemapGenerator::Sitemap.create do
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
SitemapGenerator::Sitemap.namer = SitemapGenerator::SimpleNamer.new(:genomes)
SitemapGenerator::Sitemap.create do
  Genome.all_public.find_each do |genome|
    add genome_path(genome), lastmod: genome.updated_at,
        changefreq: :weekly, priority: 0.4
    # TODO:
    # - add sample_map
  end
end

# Strains
SitemapGenerator::Sitemap.namer = SitemapGenerator::SimpleNamer.new(:strains)
SitemapGenerator::Sitemap.create do
  Strain.find_each do |strain|
    add strain_path(strain), lastmod: strain.updated_at,
        changefreq: :weekly, priority: 0.4
  end
end

# Registers
SitemapGenerator::Sitemap.namer = SitemapGenerator::SimpleNamer.new(:registers)
SitemapGenerator::Sitemap.create do
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

