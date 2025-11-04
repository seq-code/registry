
# GeoJSON list of coordinates
json.type 'FeatureCollection'
json.features(
  case params['label'].to_s.downcase
  when 'name', 'genome', 'names', 'genomes'
    @registers ||= [@register]
    @registers.map do |register|
      register.type_genomes.map do |genome|
        {
          type: 'Feature',
          geometry: {
            type: 'MultiPoint',
            coordinates: genome.sample_set.locations_complete.map(&:lon_lat)
          },
          properties: {
            name: genome.typified_names.first.try(:name),
            name_uri: genome.typified_names.first.try(:uri),
            genome: genome.text,
            genome_uri: genome.uri
          }
        } if genome.sample_set.locations_complete.any?
      end.compact
    end.reduce([], :+)
  when 'register', 'registers'
    @registers ||= [@register]
    @registers.map do |register|
      {
        type: 'Feature',
        geometry: {
          type: 'MultiPoint',
          coordinates: register.sample_set.locations_complete.map(&:lon_lat)
        },
        properties: {
          register: register.acc_url,
          title: register.propose_title
        }
      } if register.sample_set.locations_complete.any?
    end.compact
  when 'sample', 'samples'
    @sample_set.map do |sample|
      {
        type: 'Feature',
        geometry: { type: 'Point', coordinates: sample.lon_lat },
        properties: {
          sample: sample.accession,
          toponym: sample.attributes_by_type(:toponym).first
        }
      } if sample.lat_lon?
    end.compact
  else
    @sample_set.locations_complete.map do |lon_lat|
      {
        type: 'Feature',
        geometry: { type: 'Point', coordinates: lon_lat }
      }
    end
  end
)
