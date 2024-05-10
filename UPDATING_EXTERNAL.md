# Update external databases in SeqCode Registry

# Update data using LPSN download

1. Go to https://lpsn.dsmz.de/downloads
2. Download the CSV file
3. Run in the app folder:
   `RAILS_ENV=production bundle exec rake lpsn:import[/path/to/data.csv]`
4. Review the names with special messages (if any)
5. Review all newly created names

# Update data using GTDB release

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

# Update data using NCBI Taxonomy dump

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

