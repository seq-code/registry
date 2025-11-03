
# GeoJSON list of coordinates
json.type 'FeatureCollection'
json.features(
  @sample_set.locations_complete.map do |lat_lon|
    {
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: lat_lon
      }
    }
  end
)
