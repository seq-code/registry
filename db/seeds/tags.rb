# Name tagging schema: umbrella tags, their sub-tags, and standalone tags.
# Idempotent: tags are matched by slug, and existing ones are updated in place.
#
# Each entry is [slug, parent slug, color, description, prompt notes]: the
# description is shown in the UI, and the prompt notes (curation rules, edge
# cases, and co-tagging rules) are only passed to the tagging service.
#
# Colors: umbrellas use a saturated hue, their sub-tags a lighter tint of the
# same hue; standalone tags use neutral/distinct colors.

tag_seeds = [
  # Umbrellas and sub-tags
  ['geographic', nil, '#1f6f8b',
   'Name references a place or environment',
   'Assign the umbrella tag whenever assigning any geographic sub-tag.'],
  ['toponym', 'geographic', '#5fa8c4',
   'Named after a real geographic place (country, region, city, river, ' \
   'lake, ocean, mountain, etc.)',
   nil],
  ['econym', 'geographic', '#5fa8c4',
   'Named after a habitat or environmental feature (e.g. <i>marinus</i>, ' \
   '<i>lacustris</i>, <i>thermophilus</i>)',
   nil],
  ['fictional-place', 'geographic', '#5fa8c4',
   'Named after a fictional or mythological place',
   'Also assign `mythological` whenever this tag is assigned.'],
  ['metronym', 'geographic', '#5fa8c4',
   'Named after a measurement, coordinate, or physical parameter (depth, ' \
   'elevation, etc.)',
   'Also assign `geographic`. Co-tag with `trait` when the parameter is a ' \
   'physiological or ecological property of the organism rather than a ' \
   'location (e.g. a temperature range for a thermophile).'],

  ['commemorative', nil, '#7b3f8c',
   'Name references a named entity',
   'Assign the umbrella tag whenever assigning any commemorative sub-tag.'],
  ['eponym', 'commemorative', '#b386c0',
   'Named after a real person',
   nil],
  ['organonym', 'commemorative', '#b386c0',
   'Named after another organism or taxon',
   'The referenced entity must be another organism or taxon, not a ' \
   'substrate or metabolic property — use `phenonym` or `chemonym` for ' \
   'those.'],
  ['institutonym', 'commemorative', '#b386c0',
   'Named after an institution, project, or organization',
   nil],
  ['mythonym', 'commemorative', '#b386c0',
   'Named after a deity, mythological figure, or fictional person or ' \
   'character',
   'Also assign `mythological` whenever this tag is assigned.'],

  ['trait', nil, '#2e7d32',
   'Name describes a phenotypic, physiological, or metabolic property of ' \
   'the organism itself',
   'Do not use for properties of the environment, the isolation source, or ' \
   'the circumstances of discovery. Assign the umbrella tag whenever ' \
   'assigning `phenonym` or `chemonym`.'],
  ['phenonym', 'trait', '#7fbf7f',
   'Named after a phenotypic or physiological property of the organism ' \
   'itself',
   'Covers morphology, pigmentation, motility, growth form, physiology, ' \
   'etc. Do NOT use for properties of the environment, the isolation ' \
   'source, or the circumstances of discovery.'],
  ['chemonym', 'trait', '#7fbf7f',
   'Named after a chemical compound, element, or metabolic property',
   'The chemical or metabolic property must be of the organism itself, not ' \
   'of its environment.'],

  ['formed', nil, '#a8551c',
   'Name whose construction is the defining feature',
   'Assign the umbrella tag whenever assigning `acronym` or `arbitrary`.'],
  ['acronym', 'formed', '#d9955e',
   'Formed from initials or an abbreviation',
   nil],
  ['arbitrary', 'formed', '#d9955e',
   'Constructed for phonotactic or orthographic reasons',
   'Roots may still be identifiable. Can co-occur freely with content tags ' \
   '(e.g. `chemonym`).'],

  # Standalones
  ['mythological', nil, '#8c6d1f',
   'Cross-cutting tag for names referencing mythology or fiction',
   'Assign whenever `fictional-place` or `mythonym` is assigned. Do not ' \
   'assign alone.'],
  ['classical', nil, '#5d4037',
   'Epithet is a direct word from a dormant scholarly language used ' \
   'largely unmodified',
   'Covers Latin, Ancient Greek, Sanskrit, and other dormant scholarly ' \
   'languages. Not for constructed compounds or commemoratives. Can ' \
   'co-occur freely with content tags (e.g. `classical` + `phenonym` for ' \
   '*gracilis*).'],
  ['chrononym', nil, '#6d4c41',
   'Named after a time, period, season, or calendar unit',
   'Includes geological eras, seasons, times of day, and calendar-specific ' \
   'periods (e.g. a harvest month). Co-tag with `trait` when it describes a ' \
   'biological activity pattern of the organism. Co-tag with `econym` and ' \
   '`geographic` when it describes a seasonal environmental context. Assign ' \
   'no umbrella otherwise.'],
  ['numeronym', nil, '#455a64',
   'Named after a number, quantity, or order',
   'Includes ordinal/sequential use such as order of discovery (e.g. ' \
   '*primus*). Co-tag with `trait` when the number describes a property of ' \
   'the organism (e.g. *triflagellatus*). Assign no umbrella otherwise.'],
  ['masculine', nil, '#6c757d',
   'Grammatically masculine',
   'Assign only for genus, species, or subspecies ranks. Assign only when ' \
   'the gender is explicitly stated in the grammar field, or unambiguously ' \
   'determinable from the Latin/Greek declension of the referenced noun or ' \
   'root. Never infer from context alone.'],
  ['feminine', nil, '#6c757d',
   'Grammatically feminine',
   'Same rules as `masculine`.'],
  ['neuter', nil, '#6c757d',
   'Grammatically neuter',
   'Same rules as `masculine`.'],
  ['gender-uncertain', nil, '#adb5bd',
   'Gender ambiguous or explicitly uncertain',
   'Use when masc. and fem. forms are identical (e.g. most participles) or ' \
   'when the protologue explicitly notes uncertainty. Do not use when the ' \
   'gender is determinable in principle but not from the etymology as ' \
   'written — in that case assign no gender tag.']
]

tag_seeds.each do |slug, parent_slug, color, description, prompt_notes|
  tag = Tag.find_or_initialize_by(slug: slug)
  tag.name = slug.tr('-', ' ')
  tag.color = color
  tag.parent = parent_slug && Tag.find_by!(slug: parent_slug)
  tag.description = description
  tag.prompt_notes = prompt_notes
  tag.save!
end

puts "Seeded #{tag_seeds.size} tags"
