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
   nil],
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
   nil],

  ['commemorative', nil, '#7b3f8c',
   'Name references a named entity',
   nil],
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
   nil],

  ['trait', nil, '#2e7d32',
   'Name describes a phenotypic, physiological, or metabolic property of ' \
   'the organism itself',
   'Do not use for properties of the environment, the isolation source, or ' \
   'the circumstances of discovery.'],
  ['phenonym', 'trait', '#7fbf7f',
   'Named after a phenotypic or physiological property of the organism ' \
   'itself',
   'Covers morphology, pigmentation, motility, growth form, physiology, ' \
   'etc. Do NOT use for properties of the environment, the isolation ' \
   'source, or the circumstances of discovery. Generic suffixes that apply ' \
   'to virtually all organisms in the group (e.g. *-bacter*, *-bacterium*, ' \
   '*-monas*, *-microbium*, *-archaeum*) never justify this tag. Shape ' \
   'suffixes (e.g. *-coccus*, *-spirillum*, *-vibrio*) justify it only with ' \
   'medium confidence when they stand alone. A shape term modified by a ' \
   'descriptive element, or a specific morphological term such as ' \
   '*-thrix*, justifies it normally. Similarly, do not assign for terms that describe the ' \
   'organism\'s environment or ecological role rather than its own ' \
   'properties (e.g. *pelagicus* = of the open sea is `econym`, not ' \
   '`phenonym`). Do not assign for metaphorical or poetic epithets that ' \
   'describe the circumstances of discovery or a narrative about the ' \
   'organism rather than its measurable properties (e.g. *audaxviator* = ' \
   'bold traveler).'],
  ['chemonym', 'trait', '#7fbf7f',
   'Named after a chemical compound, element, or metabolic property',
   'The chemical or metabolic property must be of the organism itself, not ' \
   'of its environment.'],

  ['formed', nil, '#a8551c',
   'Name whose construction is the defining feature',
   nil],
  ['acronym', 'formed', '#d9955e',
   'Formed from initials or an abbreviation',
   nil],
  ['arbitrary', 'formed', '#d9955e',
   'Constructed for phonotactic or orthographic reasons',
   'Roots may still be identifiable. Can co-occur freely with content tags ' \
   '(e.g. `chemonym`).'],

  ['dimensional', nil, '#3949ab',
   'Name references a time, number, order, or physical measure',
   nil],
  ['chrononym', 'dimensional', '#7986cb',
   'Named after a time, period, season, or calendar unit',
   'Includes geological eras, seasons, times of day, and calendar-specific ' \
   'periods (e.g. a harvest month). Co-tag with `trait` when it describes a ' \
   'biological activity pattern of the organism. Co-tag with `econym` and ' \
   '`geographic` when it describes a seasonal environmental context.'],
  ['numeronym', 'dimensional', '#7986cb',
   'Named after a number, quantity, or order',
   'Includes ordinal/sequential use such as order of discovery (e.g. ' \
   '*primus*). Co-tag with `trait` when the number describes a property of ' \
   'the organism (e.g. *triflagellatus*).'],
  ['metronym', 'dimensional', '#7986cb',
   'Named after a measurement, coordinate, or physical parameter (depth, ' \
   'elevation, etc.)',
   'Co-tag with `geographic` (and usually `econym`) when the measure is ' \
   'locational (e.g. hadal depth in *Hadalarchaeum*). Co-tag with `trait` ' \
   'when the parameter is a physiological or ecological property of the ' \
   'organism.'],

  # Standalones
  ['mythological', nil, '#8c6d1f',
   'Cross-cutting tag for names referencing mythology or fiction',
   'Added automatically when `mythonym` or `fictional-place` is assigned; ' \
   'may also be assigned directly for other mythological references.'],
  ['literary', nil, '#ad1457',
   'Named in reference to a literary work',
   'Covers quotations, characters, places, or other elements of a literary ' \
   'work (e.g. *audaxviator*, from the Latin inscription in Jules Verne\'s ' \
   '*Journey to the Center of the Earth*). Co-occurs with `mythonym` or ' \
   '`fictional-place` when the reference is to a character or place from ' \
   'that work.'],
  ['classical', nil, '#5d4037',
   'Epithet is a direct word from a dormant scholarly language used ' \
   'largely unmodified',
   'The word must appear in classical sources largely unmodified — not ' \
   'merely constructed from classical roots. New Latin coinages built from ' \
   'Latin or Greek components (e.g. *oxygeniifera*, *diazotrophica*, ' \
   '*Methylomirabilis*) are NOT classical even if every root is Latin or ' \
   'Greek. Typical markers of New Latin construction: compound roots joined ' \
   'with connecting vowels, -fer/-vorus/-philus/-tropha suffixes on ' \
   'non-classical stems, or any term not found in classical Latin or ' \
   'Ancient Greek dictionaries.'],
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
   'written — in that case assign no gender tag. Do not use when the ' \
   'etymology explicitly states the gender; an explicit statement is ' \
   'authoritative.']
]

# Tags added automatically whenever another tag is proposed (beyond the
# tag's own umbrella), as [tag slug, implied tag slug]
tag_implication_seeds = [
  %w[mythonym mythological],
  %w[fictional-place mythological]
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

tag_implication_seeds.each do |slug, implied_slug|
  TagImplication.find_or_create_by!(
    tag: Tag.find_by!(slug: slug), implied_tag: Tag.find_by!(slug: implied_slug)
  )
end

puts "Seeded #{tag_seeds.size} tags and " \
     "#{tag_implication_seeds.size} tag implications"
