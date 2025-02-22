module Genome::SampleSet
  def sample_set
    @sample_set ||= GenomeSampleSet.new(self, source_hash)
  end
end

class GenomeSampleSet
  class << self
    def important_sample_attributes
      {
        date: %i[collection_date event_date_time_start event_date_time_end],
        location: GenomeSampleAttribute.location_keys.values.flatten,
        toponym: %i[
          geo_loc_name geographic_location_country_and_or_sea marine_region
        ],
        environment: %i[
          env_material sample_type env_biome isolation_source analyte_type
          env_broad_scale env_local_scale env_medium
          environment_biome environment_feature gold_ecosystem_classification
          broad_scale_environmental_context local_environmental_context
          environmental_medium
        ],
        other: %i[
          host ph depth temp temperature rel_to_oxygen geographic_location_depth
          chlorophyll isol_growth_condt salinity turbidity dissolved_solids
          conductivity dissolved_oxygen
        ],
        package: %i[
          ncbi_package ena_checklist ncbi_submission_package biosamplemodel
        ]
      }
    end
  end

  include Enumerable
  attr :genome, :source_hash, :samples
  def initialize(genome, source_hash)
    @genome = genome
    @source_hash = source_hash
  end

  def samples
    @samples ||= source_hash[:samples].map { |k, v| GenomeSample.new(k, v) }
  end

  def each(&blk)
    samples.each(&blk)
  end

  def empty?
    samples.empty?
  end

  def retrieved_at
    @source_hash[:retrieved_at]
  end

  def unique_attributes
    @unique_attributes ||=
      {}.tap do |h|
        each do |sample|
          sample.attributes.each do |attribute|
            h[attribute.key] ||= []
            h[attribute.key] << attribute
          end
        end
        h.each_value { |v| v.uniq! { |a| [a.key, a.value] } }
      end
  end

  def grouped_attributes
    @grouped_attributes ||=
      {}.tap do |h|
        self.class.important_sample_attributes.each do |group, attributes|
          h[group] = {}
          attributes.each do |attribute|
            attr = unique_attributes[attribute]
            h[group][attribute] = attr if attr.present?
          end
        end
      end
  end

  ##
  # Finds the locations of all source samples, and returns them as an
  # Array of 2-element Arrays [lat, lon] or +nil+
  def locations
    map(&:lat_lon).map { |i| i.empty? ? nil : i }
  end

  ##
  # Finds the rectangular bounds of all sample locations, with a minimum range
  # of latitudes and longitudes of +min+ after expanding both by a factor of
  # +pad+. Since +pad+ is a multiplicative factor, no padding is added if only
  # one location is found (but the +min+ is still applied). It returns the
  # bounds as an Array in the [south, west, north, east] order
  def locations_area(min = 0.1, pad = 0.5)
    loc = locations.compact
    return unless loc.present?

    rng = {
      lat: loc.map { |i| i[0] }.minmax,
      lon: loc.map { |i| i[1] }.minmax
    }

    rng.each do |k, v|
      width = v.inject(:-).abs
      v[0] -= width * pad / 2
      v[1] += width * pad / 2
      width = v.inject(:-).abs
      if width < min
        pad_extra = (min - width) / 2
        rng[k][0] -= pad_extra
        rng[k][1] += pad_extra
      end
    end

    [rng[:lat][0], rng[:lon][0], rng[:lat][1], rng[:lon][1]]
  end

  def extra_biosamples
    return [] if empty?

    @source_extra_biosamples ||=
      %i[derived_from sample_derived_from].map do |attribute|
        next unless attr = unique_attributes[attribute]

        attr.map do |i|
          i.value.gsub(/.*: */, '').gsub(/[\.]/, '').split(/ *,(?: and)? */)
        end
      end.flatten.compact.uniq - known_biosamples
  end

  def known_biosamples
    (map(&:accession) + (genome.try(:source_accessions) || [])).compact.uniq
  end
end

class GenomeSample
  attr :accession, :hash
  def initialize(accession, hash)
    @accession = accession.to_s
    @hash = hash
  end

  %i[title description biosample_accessions].each do |method|
    define_method(method) do
      hash[method]
    end
  end

  def attributes_raw
    hash[:attributes] || {}
  end

  def attributes
    @attributes ||=
      attributes_raw
        .map { |k, v| GenomeSampleAttribute.new(k, v) }
        .select(&:present?)
  end

  def attribute(key)
    nice_key = GenomeSampleAttribute.nice_key(key)
    attributes.find { |attribute| attribute.key == nice_key }
  end

  def attribute_by_raw_key(raw_key)
    attributes.find { |attribute| attribute.raw_key == raw_key }
  end

  def [](key)
    attribute(key)
  end

  def lat_lon
    @lat_lon ||=
      [].tap do |a|
        attributes.each do |attribute|
          case attribute.location_type
          when :lat_lon
            a[0], a[1] = attribute.value
          when :lat
            a[0] = attribute.value
          when :lon
            a[1] = attribute.value
          end
        end
      end
  end
end

class GenomeSampleAttribute
  class << self
    def missing
      [
        'not provided', 'not collected', 'unavailable', 'not applicable',
        'missing', '-', 'n/a', 'null', ''
      ]
    end

    def location_keys
      {
        lat_lon: %i[lat_lon],
        lat: %i[lat geographic_location_latitude latitude_start latitude_end],
        lon: %i[lon geographic_location_longitude longitude_start longitude_end]
      }
    end

    def nice_key(raw_key)
      raw_key
        .to_s.downcase.gsub(/[^A-Za-z0-9]/, '_')
        .gsub(/_+/, '_').gsub(/^_|_$/, '')
        .to_sym
    end

    def parse_location_coordinate(string, type)
      coord = /([-+] *)?(\d+(?:[\.\,]\d+)?|\d+°(?:\d+['"])*)( *[NSEW])?/
      m = (string.match(/^#{coord}$/i) || [])[1..3].map(&:to_s).map(&:strip)

      decimal =
        if sg = m[1].match(/^(\d) *°(?: *(\d+) *'(?: *(\d+) *(?:"|''))?)?/)
          sg[1].to_f + (sg[2].to_f + sg[3].to_f / 60) / 60
        else
          m[1].gsub(',', '.').to_f
        end

      allowed_dir = { lat: %w[S s N n], lon: %w[W w E e] }
      if m[2].present? && !allowed_dir[type.to_sym].include?(m[2])
        warn 'unexpected direction for %s: %s' % [type, m[2]]
        return nil
      end

      if %w[S s W w].include?(m[2]) || m[0] == '-'
        -decimal
      else
        decimal
      end
    end
  end

  attr :raw_key, :raw_value, :key, :value
  def initialize(key, value)
    @raw_key = key.to_s.strip
    @raw_value = value.to_s.strip
  end

  def key
    @key ||= self.class.nice_key(raw_key)
  end

  def value
    @value ||= missing_value? ? nil : (as_location || raw_value)
  end

  def present?
    !value.nil?
  end

  def missing_value?
    self.class.missing.include?(raw_value.downcase)
  end

  def location?
    !location_type.nil?
  end

  def location_type
    self.class.location_keys.each do |k, v|
      return k if v.include?(key)
    end
    nil
  end

  def as_location
    return unless missing_value? || location?

    coord = /([-+] *)?(\d+(?:[\.\,]\d+)?|\d+°(?:\d+['"])*)( *[NSEW])?/
    if location_type == :lat_lon
      m = raw_value.match(/^(#{coord})[ ,;\/\-]+(#{coord})$/i) || []
      [
        self.class.parse_location_coordinate(m[1], :lat),
        self.class.parse_location_coordinate(m[5], :lon)
      ]
    else
      self.class.parse_location_coordinate(raw_value, location_type)
    end
  end

  def as_location_s
    case location_type
    when :lat_lon
      '%.4g %s %.4g %s' % [
        value[0].abs, value[0].positive? ? 'N' : 'S',
        value[1].abs, value[1].positive? ? 'E' : 'W'
      ]
    when :lat
      '%.4g %s' % [value.abs, value.positive? ? 'N' : 'S']
    when :lon
      '%.4g %s' % [value.abs, value.positive? ? 'E' : 'W']
    end
  end

  def value_to_s
    if location?
      as_location_s
    else
      value.to_s
    end
  end

  def eql?(other)
    key == other.key && value == other.value
  end

  def ==(other)
    eql? other
  end
end
