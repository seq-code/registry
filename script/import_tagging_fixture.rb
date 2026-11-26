# Load a tagging evaluation fixture (see ~/work/eval-data/prepare_fixture.py)
# into an empty development database whose tags were loaded from
# db/seeds/tags.rb. Development only.
#
#   bin/rails runner script/import_tagging_fixture.rb fixture.json

abort 'Refusing to run outside development' unless Rails.env.development?

data = JSON.parse(File.read(ARGV.fetch(0)))
now = Time.current
columns = Name.column_names

keys = data['names'].flat_map(&:keys).uniq & columns
rows = data['names'].map do |n|
  keys.index_with { |k| n[k] }.merge('created_at' => now, 'updated_at' => now)
end
# Parents first is not required by insert_all, but parent_id must exist:
# insert without parents, then set them
Name.insert_all!(rows.map { |r| r.merge('parent_id' => nil) })
data['names'].each do |n|
  Name.where(id: n['id']).update_all(parent_id: n['parent_id']) if n['parent_id']
  next unless n['etymology_text']

  # Etymologies that couldn't be reconstructed stay as free text
  ActionText::RichText.create!(
    record_type: 'Name', record_id: n['id'], name: 'etymology_text',
    body: ERB::Util.html_escape(n['etymology_text'])
  )
end

tags = Tag.pluck(:slug, :id).to_h
missing = data['name_tags'].map { |nt| nt['tag'] } - tags.keys
abort "Unknown tags in fixture: #{missing.uniq.join(', ')}" if missing.any?
NameTag.insert_all!(
  data['name_tags'].map do |nt|
    { name_id: nt['name_id'], tag_id: tags[nt['tag']],
      status_int: nt['status_int'], created_at: now, updated_at: now }
  end
)
seq = ActiveRecord::Base.connection
seq.execute("SELECT setval('names_id_seq', (SELECT MAX(id) FROM names))")
puts "Imported #{Name.count} names, #{NameTag.count} name tags " \
     "(#{NameTag.where(status_int: 1).count} accepted)"
