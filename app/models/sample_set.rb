# Abstract class that requires extension implementing the initialization,
# +samples+, and +source_object+ methods
class SampleSet
  class << self
    def important_sample_attributes
      {
        date: %i[collection_date event_date_time_start event_date_time_end],
        location: GenomeSampleAttribute.location_keys.values.flatten,
        toponym: %i[
          geo_loc_name geographic_location_country_and_or_sea marine_region
          geographic_location_country_and_or_sea_region
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

  attr :samples
  
  def each(&blk)
    samples.each(&blk)
  end

  def empty?
    samples.empty?
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

  def known_biosamples
    [
      map(&:accession),
      map(&:biosample_accessions),
      genome.try(:source_accessions),
    ].flatten.compact.uniq
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
      # A simple (positive) number, no captures
      num = /[\d\.,]+/
      # A sexagesimal coordinate (without direction), captures:
      # 1. Degrees
      # 2. Minutes
      # 3. Seconds
      sg_coord =
        /(#{num}) *°(?: *(#{num}) *['′](?: *(#{num}) *(?:"|″|''|′′))?)?/
      # A generic coordinate (complete), captures:
      # 1. Sign (plus, minus, or nil)
      # 2. The numeric part of the coordinate (decimal or sexagesimal)
      # 3-5. Degrees, minutes, seconds (only if sexagesimal)
      # 6. Direction (N, S, E, W, nil), can be lowercase too
      coord = /([-+])? *(#{num}|#{sg_coord}) *([NSEW])?/
      match = string&.match(/^#{coord}$/i) or return
      m = match.values_at(1, 2, 6).map(&:to_s).map(&:strip)

      decimal =
        if sg = m[1].match(/^#{sg_coord}/i)
          sg = sg.to_a.map { |i| i&.gsub(',', '.').to_f }
          sg[1] + (sg[2] + sg[3] / 60) / 60
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

    def location_coordinate_to_string(float, type)
      return 'Not parsed: %s' % float unless float.is_a?(Float)
      dir = { lat: %w[N S], lon: %w[E W] }[type.to_sym][float.positive? ? 0 : 1]
      base = float.abs
      deg = base.floor
      base -= deg.to_f
      y = '%i°' % deg
      unless base.zero?
        min = (base * 60).floor
        y += ' %i′' % min
        base -= min.to_f / 60
        sec = (base * 60 * 60).round(2)
        y += ' %.2g″' % sec unless sec.zero?
      end
      y + ' ' + dir
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
      return 'Not parsed: %s' % value.to_s unless value.is_a?(Array)

      '%s, %s' % [
        self.class.location_coordinate_to_string(value[0], :lat),
        self.class.location_coordinate_to_string(value[1], :lon)
      ]
    when :lat, :lon
      self.class.location_coordinate_to_string(value, location_type)
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
