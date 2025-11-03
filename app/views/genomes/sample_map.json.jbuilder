
# GeoJSON list of coordinates
locs = @sample_set.locations_complete
json.type 'FeatureCollection'
json.features(
  locs.map do |lat_lon|
    {
      type: 'Feature',
      geometry: {
        type: 'Point',
        coordinates: lat_lon
      }
    }
  end
)
