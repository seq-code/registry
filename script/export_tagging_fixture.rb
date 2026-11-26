# Export the minimal data needed to evaluate TaggingService offline: the gold
# names (names with at least one accepted tag), the names in their lineages
# (for genus gender), and their name tags. Read-only.
#
#   bin/rails runner script/export_tagging_fixture.rb [OUTPUT.json]
#
# Only names with a public status are exported (Name.public_status), unless
# ALL_STATUSES=1. Set TAGS=1 to also export the tags and implications as they
# are in the database (by default they are taken from db/seeds/tags.rb).
#
# Exported per name: id, name, rank, status, lineage parent id, the
# structured etymology columns, and the free-text etymology (if any). Nothing
# else: no users, registers, notes, correspondence, or proposer identities.

require 'json'

output = ARGV.first.presence || 'tagging_fixture.json'
public_only = ENV['ALL_STATUSES'] != '1'

ETYMOLOGY_COLUMNS =
  Name.column_names.grep(/\Aetymology_(p\d|xx)_(lang|grammar|particle|description)\z/)
      .freeze

accepted = NameTag.where(status_int: NameTag.status.index(:accepted))
gold = Name.where(id: accepted.select(:name_id)).order(:id)
skipped = public_only ? gold.where.not(status: Name.public_status).count : 0
gold = gold.where(status: Name.public_status) if public_only

# Gold names and every name in their lineages, keyed by id. Lineage parents
# are recorded explicitly, as they can come from placements (incertae sedis)
names = {}
gold.find_each do |name|
  lineage = name.lineage(with_self: true)
  lineage.each_with_index do |member, i|
    next if names.key?(member.id)

    names[member.id] = [member, i.zero? ? nil : lineage[i - 1].id]
  end
end
non_public_ancestors =
  names.values.count { |n, _| !Name.public_status.include?(n.status) }

name_rows = names.values.sort_by { |n, _| n.id }.map do |name, parent_id|
  row = {
    'id' => name.id, 'name' => name.name, 'rank' => name.rank,
    'status' => name.status, 'parent_id' => parent_id
  }
  ETYMOLOGY_COLUMNS.each { |col| row[col] = name[col] if name[col].present? }
  row['etymology_text'] = name.etymology_text.body.to_html if name.etymology_text?
  row
end

slugs = Tag.pluck(:id, :slug).to_h
name_tags =
  NameTag.where(name_id: gold.select(:id)).order(:name_id, :tag_id).map do |nt|
    {
      'name_id' => nt.name_id, 'tag' => slugs[nt.tag_id],
      'status_int' => nt.status_int,
      'pre_cascade_status_int' => nt.pre_cascade_status_int
    }
  end

data = {
  'meta' => {
    'exported_at' => Time.now.utc.iso8601,
    'public_only' => public_only,
    'gold_names' => gold.count,
    'gold_names_skipped_non_public' => skipped,
    'names_including_lineage' => name_rows.size,
    'non_public_lineage_names' => non_public_ancestors,
    'name_tags' => name_tags.size
  },
  'names' => name_rows,
  'name_tags' => name_tags
}

if ENV['TAGS'] == '1'
  data['tags'] = Tag.with_rich_text_description.order(:slug).map do |tag|
    {
      'slug' => tag.slug, 'parent' => tag.parent&.slug, 'color' => tag.color,
      'description' => tag.description&.to_plain_text,
      'prompt_notes' => tag.prompt_notes, 'excluded_bases' => tag.excluded_bases
    }
  end
  data['tag_implications'] =
    TagImplication.all.map { |ti| [slugs[ti.tag_id], slugs[ti.implied_tag_id]] }
end

File.write(output, JSON.pretty_generate(data))
puts data['meta'].map { |k, v| "#{k}: #{v}" }
puts "Written to #{output}"
