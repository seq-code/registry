# Update SeqCode Registry using external databases

## Update data using LPSN download

1. To protect manually modified data, run in the app folder:
   `RAILS_ENV=production bundle exec rake lpsn:protect[/path/to/last/data.csv]`
2. Go to https://lpsn.dsmz.de/downloads
3. Download the CSV file
4. Run in the app folder:
   `RAILS_ENV=production bundle exec rake lpsn:import[/path/to/data.csv]`
5. Review the names with special messages (if any)
6. Review all newly created names

## Update data using GTDB release

1. Create a release directory and download taxonomy tables:
   ```bash
   mkdir ~/gtdb_release
   cd ~/gtdb_release
   wget https://data.gtdb.ecogenomic.org/releases/latest/ar53_taxonomy.tsv.gz
   wget https://data.gtdb.ecogenomic.org/releases/latest/bac120_taxonomy.tsv.gz
   ```
2. Run in the app folder:
   `RAILS_ENV=production bundle exec rake gtdb:import[$HOME/gtdb_release]`
3. Review all newly created names
4. Update the release information in `app/helpers/placements_helper.rb`

## Update data using NCBI Taxonomy dump

1. Download and untarball the taxonomy dump:
   ```bash
   mkdir ~/ncbi_taxdump
   cd ~/ncbi_taxdump
   wget https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
   tar -zxvf taxdump.tar.gz
   ```
2. Run in the app folder:
   `RAILS_ENV=production bundle exec rake ncbi:import[$HOME/ncbi_taxdump]`
3. Review all newly created names
4. Update the release information in `app/helpers/placements_helper.rb`

# Update external databases with SeqCode Registry data

## Update NCBI LinkOut

1. Download the complete linkout XML:
   ```bash
   wget -O resources_1.xml 'https://registry.seqco.de/names/linkout.xml?per_page=10000&page=1'
   wget -O resources_2.xml 'https://registry.seqco.de/names/linkout.xml?per_page=10000&page=2'
   wget -O resources_3.xml 'https://registry.seqco.de/names/linkout.xml?per_page=10000&page=3'
   wget -O resources_4.xml 'https://registry.seqco.de/names/linkout.xml?per_page=10000&page=4'
   ```
2. Upload to the private FTP

## Update Wikidata

This should automatically update every day, but just in case that fails or needs
to be manually performed:

1. Run in the app folder:
   `RAILS_ENV=production bundle exec rake wikidata:push`

