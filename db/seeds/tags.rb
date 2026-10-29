# Name tagging schema: umbrella tags, their sub-tags, and standalone tags.
# Idempotent: tags are matched by slug, and existing ones are updated in place.
#
# Colors: umbrellas use a saturated hue, their sub-tags a lighter tint of the
# same hue; standalone tags use neutral/distinct colors.

tag_seeds = [
  # Umbrellas and sub-tags
  ['geographic', nil, '#1f6f8b',
   'Name references a place or environment'],
  ['toponym', 'geographic', '#5fa8c4',
   'Named after a real geographic place (country, region, city, river, ' \
   'lake, ocean, mountain, etc.)'],
  ['econym', 'geographic', '#5fa8c4',
   'Named after a habitat or environmental feature (e.g., <i>marinus</i>, ' \
   '<i>lacustris</i>, <i>thermophilus</i>)'],
  ['fictional-place', 'geographic', '#5fa8c4',
   'Named after a fictional or mythological place'],
  ['metronym', 'geographic', '#5fa8c4',
   'Named after a measurement, coordinate, or physical parameter (depth, ' \
   'elevation, etc.); co-tag with <code>trait</code> when the parameter is ' \
   'a physiological/ecological property rather than a location'],

  ['commemorative', nil, '#7b3f8c',
   'Name references a named entity'],
  ['eponym', 'commemorative', '#b386c0',
   'Named after a real person (scientist, explorer, local figure, etc.)'],
  ['organonym', 'commemorative', '#b386c0',
   'Named after another organism or taxon'],
  ['institutonym', 'commemorative', '#b386c0',
   'Named after an institution, project, or organization'],
  ['mythonym', 'commemorative', '#b386c0',
   'Named after a deity, mythological figure, or fictional person/character'],

  ['trait', nil, '#2e7d32',
   'Name describes a property or character of the organism or its context'],
  ['phenonym', 'trait', '#7fbf7f',
   'Named after a phenotypic trait (morphology, pigmentation, physiology, ' \
   'etc.)'],
  ['chemonym', 'trait', '#7fbf7f',
   'Named after a chemical compound, element, or metabolic property'],
  ['chrononym', 'trait', '#7fbf7f',
   'Named after a time, period, season, or calendar unit — including ' \
   'geological eras, seasons, times of day, and calendar-specific periods ' \
   '(e.g., a harvest month); co-tag with <code>phenonym</code> when ' \
   'describing a biological activity pattern, or with <code>econym</code> ' \
   'when describing a seasonal environmental context'],
  ['numeronym', 'trait', '#7fbf7f',
   'Named after a number, quantity, or order — including ordinal/sequential ' \
   'use (e.g., order of discovery, as in <i>primus</i>)'],

  ['formed', nil, '#a8551c',
   'Name whose construction is the defining feature'],
  ['acronym', 'formed', '#d9955e',
   'Formed from initials or an abbreviation (project name, institution, ' \
   'gene, etc.)'],
  ['arbitrary', 'formed', '#d9955e',
   'Constructed for phonotactic or orthographic reasons; roots may still be ' \
   'identifiable; can co-occur with content tags'],

  # Standalones
  ['mythological', nil, '#8c6d1f',
   'Cross-cutting convenience tag — assigned to all names tagged ' \
   '<code>fictional-place</code> or <code>mythonym</code>'],
  ['classical', nil, '#5d4037',
   'Epithet is a direct word from a dormant scholarly language (Latin, ' \
   'Ancient Greek, Sanskrit, etc.) used largely unmodified, rather than a ' \
   'constructed compound or a commemorative; can co-occur with content tags'],
  ['masculine', nil, '#6c757d',
   'Grammatically masculine'],
  ['feminine', nil, '#6c757d',
   'Grammatically feminine'],
  ['neuter', nil, '#6c757d',
   'Grammatically neuter'],
  ['gender-uncertain', nil, '#adb5bd',
   'Gender ambiguous or explicitly uncertain (e.g., identical masc./fem. ' \
   'forms such as participles, or explicit uncertainty in the protologue)']
]

tag_seeds.each do |slug, parent_slug, color, description|
  tag = Tag.find_or_initialize_by(slug: slug)
  tag.name = slug.tr('-', ' ')
  tag.color = color
  tag.parent = parent_slug && Tag.find_by!(slug: parent_slug)
  tag.description = description
  tag.save!
end

puts "Seeded #{tag_seeds.size} tags"
