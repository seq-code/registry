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
   'Assign alone, without any sub-tag, for broad regions defined by ' \
   'position, such as the poles or a hemisphere, and for names describing ' \
   'a broad or cosmopolitan distribution (everywhere, many places, many ' \
   'environments; e.g. *ubiqueversans*), without `econym` or `toponym`. ' \
   'When such a name also expresses a vague quantity (e.g. *pluralis*, ' \
   '*multi-*, *multiplex*), add `dimensional` alone as well (e.g. ' \
   '*Pluralincolimonas*, *Multiplicimicrobium*). Habitat details that ' \
   'appear only in the explanation (e.g. occurring in the subsurface) do ' \
   'not justify this tag unless the name itself refers to them.'],
  ['toponym', 'geographic', '#5fa8c4',
   'Named after a real geographic place (country, region, city, river, ' \
   'lake, ocean, mountain, etc.), including extraterrestrial places',
   'Assign only when the name itself is derived from the place. Do not ' \
   'assign when the etymology mentions a place merely as context — e.g. ' \
   'the range of a referenced organism (\'a bird endemic to Australia\'), ' \
   'or a site mentioned in passing — unless the name is formed from that ' \
   'place. Broad regions defined by position, such as the poles or a ' \
   'hemisphere (e.g. *polaris*, *meridionalis*), are `geographic` but not ' \
   '`toponym`. A habitat type (e.g. a mine, a swamp) is `econym`, not ' \
   '`toponym`. Named regions such as Antarctica (e.g. *antarcticus*) ' \
   'and extraterrestrial places (e.g. Titan, Saturn\'s moon) remain ' \
   '`toponym`. A person honoured for work in or on a place (e.g. ' \
   '*allenii*, named for Eugene T. Allen for his work on the geochemistry ' \
   'of Yellowstone National Park) is `eponym` only, not `toponym`. ' \
   'Likewise, a study site mentioned only as context is not `toponym` ' \
   '(e.g. *Bilamarchaeum*, \'turtle lands\'). A word derived from a place ' \
   'name but used generically (e.g. *geysiri*, of a geyser, from Icelandic ' \
   'Geysir) is `econym`, not `toponym`.'],
  ['econym', 'geographic', '#5fa8c4',
   'Named after a habitat or environmental feature (e.g. <i>marinus</i>, ' \
   '<i>lacustris</i>, <i>hydrothermalis</i>)',
   'Includes a named body part or organ used as habitat (e.g. gut, rumen, ' \
   'liver; <i>Ruminimicrobium</i>), and words describing the habitat even ' \
   'when formed from a verb or participle (e.g. <i>mesodigestus</i>, ' \
   'referring to a mesophilic digester), which are not `phenonym`, and ' \
   'words derived from a place name but used generically (e.g. ' \
   '<i>geysiri</i>, of a geyser), which are not `toponym`. A host taxon ' \
   '(e.g. a coral or sponge genus in -cola names, or a host in the ' \
   'genitive such as <i>termitum</i>, of termites) is `organonym`, not ' \
   '`econym`; a name referring to both gets both (e.g. ' \
   '<i>hominiciens</i>, in the human gut). Mere position relative to a ' \
   'host (e.g. endo-, ecto-, inside, outside) is neither. A compartment ' \
   'that exists only inside a living host cell (e.g. nucleus, cytoplasm, ' \
   'vacuole, the periplasm of a host) is this tag and also `lifestyle`, ' \
   'as it implies an intracellular symbiosis (e.g. <i>Nucleicultrix</i>, ' \
   'inhabitant of the nucleus). Habitat details ' \
   'that appear only in the explanation (e.g. occurring in the ' \
   'subsurface, presence in brackish water, living in darkness) do not ' \
   'justify this tag unless the name itself refers to them. A ' \
   'temperature word qualifying a habitat noun (e.g. <i>Hydrothermus</i>, ' \
   'living in hot water; a hot spring) is this tag and does not add ' \
   '`phenonym`, but one describing the organism itself (e.g. ' \
   '<i>Caldarchaeum</i>, a warm archaeon; <i>thermophilum</i>) is ' \
   '`phenonym`, not this tag.'],
  ['fictional-place', 'geographic', '#5fa8c4',
   'Named after a fictional or mythological place',
   'E.g. *Acheron*, the underworld river, or Hades as the underworld. A ' \
   'mythological place is this tag, not `mythonym`, which is only for ' \
   'figures and deities.'],

  ['commemorative', nil, '#7b3f8c',
   'Name references a named entity',
   nil],
  ['eponym', 'commemorative', '#b386c0',
   'Named after a real person',
   nil],
  ['organonym', 'commemorative', '#b386c0',
   'Named after another organism or taxon',
   'The referenced entity must be another organism or taxon. Chemical ' \
   'substances and metabolic properties are `chemonym` or `phenonym`; ' \
   'organism-derived material degraded or consumed as a substrate (e.g. ' \
   '*phytovorans*, degrading plant material) is `phenonym`; and a ' \
   'mythological or fictional character, even an animal, is `mythonym`. ' \
   'The name counts as an organonym even when phrased as \'from the ' \
   'land of X\' or \'from the X lands\', where X is an organism (e.g. ' \
   '*Bilamarchaeum*, *Burarchaeum*); any indirect place reference is ' \
   'secondary. However, when the etymology explicitly names a specific ' \
   'place (e.g. a reserve, park, or site) as the basis of the name, assign ' \
   '`toponym` with high confidence and not `organonym`, even if that place ' \
   'is itself named after an organism (e.g. *Pristimantibacillus*, from ' \
   'the Pristimantis natural reserve). Collective terms for organisms ' \
   'that are not taxa (e.g. plankton, biofilm, microbiota) are not ' \
   '`organonym`, and neither is a domain or other very broad group implied ' \
   'by a generic suffix (e.g. within Archaea, for *-archaeum*). An ' \
   'affinity term (e.g. *-philus*, *-phila*) combined with a host ' \
   'organism is `organonym` and `lifestyle` (e.g. *amoebiphila*). A host taxon (e.g. a coral or sponge genus in *-cola* ' \
   'names, or a host in the genitive such as *termitum*, of termites) is ' \
   '`organonym`, not `econym`; a named ' \
   'body part or organ of the host used as habitat is also `econym` (e.g. ' \
   '*hominiciens*, in the human gut). Mere position relative to a host ' \
   '(e.g. *endo-*, *ecto-*, inside, outside) is neither. Merely living in ' \
   'or on a host, or being associated with one (e.g. *-cola* names on a ' \
   'host taxon, *Doriopsillibacter*, *Tyloplasma*) is `organonym` only, ' \
   'not `lifestyle`; a named ' \
   'host or prey co-occurs with `lifestyle` only when the name describes ' \
   'the nature of the relationship (e.g. *archaeovorus*).'],
  ['institutonym', 'commemorative', '#b386c0',
   'Named after an institution, project, or organization',
   'When the institution is referenced through its acronym (e.g. ANSTO, ' \
   'CAS), also assign `acronym`.'],
  ['mythonym', 'commemorative', '#b386c0',
   'Named after a deity, mythological figure, or fictional person or ' \
   'character',
   'Includes mythological or fictional animals, which are `mythonym` and ' \
   'not `organonym`. Only for figures and deities: a mythological or ' \
   'fictional place (e.g. *Acheron*; Hades as the underworld) is ' \
   '`fictional-place`.'],
  ['ethnonym', 'commemorative', '#b386c0',
   'Named after a people, ethnic group, clan, or community',
   'Not for individual persons (use `eponym`). A place mentioned only as ' \
   'where the group lives or lived does not by itself justify `toponym`.'],

  ['trait', nil, '#2e7d32',
   'Name describes a phenotypic, physiological, or metabolic property of ' \
   'the organism itself, or its lifestyle',
   'Do not use for properties of the environment, the isolation source, or ' \
   'the circumstances of discovery.'],
  ['phenonym', 'trait', '#7fbf7f',
   'Named after a phenotypic or physiological property of the organism ' \
   'itself, including metabolism (also of organism-derived substrates) ' \
   'but not interactions with living organisms (see `lifestyle`)',
   'Covers morphology, pigmentation, motility, growth form, physiology ' \
   '(including temperature preference, when a temperature word describes ' \
   'the organism itself, e.g. *Caldarchaeum*, a warm archaeon; ' \
   '*Thermobaculum*, hot small rod; *thermophilum*), and metabolism ' \
   '(substrates used or degraded, compounds produced, or ' \
   'processes such as nitrogen fixation or fermentation). Independent of ' \
   '`chemonym`: a metabolism naming a substance or particle (e.g. ' \
   'sulfur-metabolizing, electron-eating) is both, and one naming none ' \
   '(e.g. fermenting) is only `phenonym`. The size of the organism (e.g. ' \
   '*nano-*, *micro-*, *minutus*) is also `dimensional`, without a ' \
   'sub-tag. Do NOT use for properties of ' \
   'the environment, the isolation source, or the circumstances of discovery. Generic suffixes denoting a ' \
   'microorganism in general (e.g. *-bacter*, *-bacterium*, *-bacillus*, ' \
   '*-baculum*, *-monas*, *-microbium*, *-archaeum*) never justify this tag at any ' \
   'confidence level, and neither do diminutive suffixes (e.g. *-ellum*, ' \
   '*-ella*, *-ula*). Shape suffixes (e.g. *-coccus*, *-spirillum*, ' \
   '*-vibrio*) justify it only with medium confidence when they stand ' \
   'alone. A shape term ' \
   'modified by a descriptive element, or a specific morphological term ' \
   'such as *-thrix*, justifies it normally. Similarly, do not assign for ' \
   'terms that describe the organism\'s environment or ecological role ' \
   'rather than its own properties (e.g. *pelagicus* = of the open sea is ' \
   '`econym`, not `phenonym`), even when formed from a verb or participle ' \
   '(e.g. *mesodigestus*, referring to a mesophilic digester). Do not ' \
   'assign for metaphorical or poetic ' \
   'epithets that describe the circumstances of discovery or a narrative ' \
   'about the organism rather than its measurable properties (e.g. ' \
   '*audaxviator* = bold traveler). Terms describing abundance, dominance, ' \
   'commonness, or distribution (e.g. *commune*, *subdominans*, ' \
   '*ubiqueversans*) are not organismal traits; do not assign this tag or ' \
   '`trait` for them. Abundance, dominance, and commonness, including ' \
   'relative abundance (e.g. *abundans*, *subdominans*, *regnum*, ' \
   '*commune*, *vulgaris*), are `dimensional`, and a broad distribution ' \
   'is `geographic`; a word taken from a host\'s name (e.g. *Hepatoplasma ' \
   'vulgare*, after *Armadillidium vulgare*) is `organonym` only. Other ' \
   'properties in the same name can still be this tag (e.g. ' \
   '*Regnicoccus* for *-coccus*). Interactions with other living organisms ' \
   '(predation, parasitism, pathogenesis, symbiosis, commensalism, or ' \
   'epibiosis) are `lifestyle`, not this tag; other properties of such ' \
   'names can still be (e.g. the size in *Nanoclepta*). Degrading or ' \
   'consuming organism-derived material as a substrate (e.g. plant ' \
   'biomass, lignocellulose, chitin, dead cells; *phytovorans*) is this ' \
   'tag, not `lifestyle`.'],
  ['lifestyle', 'trait', '#7fbf7f',
   'Named after the interaction of the organism with other living ' \
   'organisms: predation, parasitism, pathogenesis, symbiosis, ' \
   'commensalism, or epibiosis',
   'Use only when the name describes the nature of the relationship (e.g. ' \
   '*symbiosum*, living together with; *Nanoclepta*, steals from its ' \
   'host; *archaeovorus*, archaea-devouring; the *-socius* genera such as ' \
   '*Spongiisocius* and *Poriferisocius*, companion). Degrading or ' \
   'consuming organism-derived material as a substrate (e.g. plant ' \
   'biomass, lignocellulose, chitin, dead cells; *phytovorans*) is ' \
   '`phenonym`, not `lifestyle`. Merely living in or on a host, or being ' \
   'associated with one (e.g. *-cola* names on a host taxon; inhabiting a ' \
   'host, as in *Doriopsillibacter*; associated with the host Tylos, as ' \
   'in *Tyloplasma*) is `organonym` only, not `lifestyle`. The ' \
   'relationship itself does not justify `phenonym`. Co-tag with ' \
   '`organonym` when the host or prey is named. An affinity term (e.g. ' \
   '*-philus*, *-phila*) combined with a host organism describes the ' \
   'relationship (e.g. *amoebiphila*, amoeba-loving), unlike *-cola* or ' \
   'inhabiting a host, which are `organonym` only. Exception: a habitat ' \
   'that exists only inside a living host cell (e.g. nucleus, cytoplasm, ' \
   'vacuole, the periplasm of a host) implies an intracellular symbiosis, ' \
   'so it is this tag and `econym` even though the name does not describe ' \
   'the relationship (e.g. *Nucleicultrix*, inhabitant of the nucleus). ' \
   'Body parts and organs (e.g. gut, rumen, liver) are `econym` only, and ' \
   'mere position (e.g. inside, endo-) is neither.'],

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
   'Name references a time, number, order, quantity, physical measure, ' \
   'abundance, or the size of the organism',
   'Assign alone, without any sub-tag, for names referring to: the size ' \
   'of the organism (e.g. *nano-*, *micro-*, *minutus*), together with ' \
   '`phenonym`; vague quantities (many, multiple; e.g. *multihospitum*) ' \
   'or solitude and singularity (alone, sole, single; e.g. *deserta*, ' \
   '*singularis*), instead of `numeronym`; abundance, dominance, or commonness, ' \
   'including relative abundance (e.g. *abundans*, *subdominans*, ' \
   '*regnum*, *commune*, *vulgaris*), instead of `phenonym`; or a vague ' \
   'quantity in a name describing a broad distribution, together with ' \
   '`geographic` (e.g. *Pluralincolimonas*, *Multiplicimicrobium*). Add ' \
   '`geographic` to commonness when the etymology explicitly describes a ' \
   'wide distribution (widespread, found everywhere). A word taken from a ' \
   'host\'s name describes the host, so the name is `organonym` only (e.g. ' \
   '*Hepatoplasma vulgare*, after *Armadillidium vulgare*). The generic ' \
   'suffix *-microbium* is not a size reference, and diminutive suffixes ' \
   '(e.g. *-ellum*, *-ella*, *-ula*) are generic and do not justify this ' \
   'tag.'],
  ['chrononym', 'dimensional', '#7986cb',
   'Named after a time, period, season, or calendar unit',
   'Includes geological eras, seasons, times of day, and calendar-specific ' \
   'periods (e.g. a harvest month). Co-tag with `trait` when it describes a ' \
   'biological activity pattern of the organism. Co-tag with `econym` and ' \
   '`geographic` when it describes a seasonal environmental context.'],
  ['numeronym', 'dimensional', '#7986cb',
   'Named after a specific number or order',
   'Includes ordinal/sequential use such as order of discovery (e.g. ' \
   '*primus*). Co-tag with `trait` when the number describes a property of ' \
   'the organism (e.g. *triflagellatus*). Vague quantities (many, ' \
   'multiple; e.g. *multihospitum*) and solitude or singularity (alone, ' \
   'sole, single; e.g. *deserta*, *singularis*) are `dimensional` alone, ' \
   'not this tag.'],
  ['metronym', 'dimensional', '#7986cb',
   'Named after a measurement, coordinate, or physical parameter (depth, ' \
   'elevation, etc.)',
   'Only for explicit measurements or values (e.g. depth, temperature, or ' \
   'altitude figures), not qualitative adjectives such as deep or cold. ' \
   'Co-tag with `geographic` (and usually `econym`) when the measure is ' \
   'locational (e.g. hadal depth in *Hadalarchaeum*). Co-tag with `trait` ' \
   'when the parameter is a physiological or ecological property of the ' \
   'organism. Not for the size of the organism: use `dimensional` alone ' \
   '(with `phenonym`).'],

  # Standalones
  ['chemonym', nil, '#00838f',
   'Named after a chemical substance or particle (element, ion, compound, ' \
   'functional group, chemical mixture such as oil or salt, or a particle ' \
   'such as the electron)',
   'Decide by what the root names, not by what it says about the ' \
   'organism. Independent of `phenonym` (and so of `trait`): a substance ' \
   'in the habitat (e.g. of oil sand, belonging to salt) is only ' \
   '`chemonym`, and a metabolism naming a substance or particle (e.g. ' \
   'sulfur-metabolizing, electron-eating) is both.'],
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
  ['vernacular', nil, '#f9a825',
   'Name derived from a word of a living or non-classical language',
   'Applies to vocabulary (nouns, adjectives, verbs) taken from a ' \
   'non-classical language (e.g. Dharawal *gugara*, kookaburra; *bilama*, ' \
   'freshwater turtle). Not for personal names or place names that are ' \
   'merely Latinized. Can co-occur with `indigenous` and with content ' \
   'tags. Not for words from dormant languages (e.g. Akkadian, Sanskrit); ' \
   'use `classical` for those.'],
  ['indigenous', nil, '#d84315',
   'Name derived from a word or name of an Indigenous language or culture',
   'Covers vocabulary, clan or group names, and mythological figures from ' \
   'Indigenous languages and cultures (e.g. Dharawal *buru*; the ' \
   'Norongarragal clan; Tiddalik). Can co-occur with `vernacular`, ' \
   '`ethnonym`, `mythonym`, and content tags. Only for Indigenous ' \
   'languages and cultures: e.g. Icelandic (as in *geysiri*) is not one.'],
  ['classical', nil, '#5d4037',
   'Name or epithet is a single word from a dormant scholarly language, ' \
   'used largely unmodified',
   'The word must appear in classical sources largely unmodified — not ' \
   'merely constructed from classical roots. Compounds and New Latin ' \
   'coinages built from Latin or Greek components (e.g. *oxygeniifera*, ' \
   '*diazotrophica*, *Methylomirabilis*, *Elulimicrobium*) are NOT ' \
   'classical even if every root is Latin or Greek; if proposed for a ' \
   'compound at all, use low confidence. Typical markers of New Latin construction: compound roots joined ' \
   'with connecting vowels, -fer/-vorus/-philus/-tropha suffixes on ' \
   'non-classical stems, or any term not found in dictionaries of ' \
   'classical Latin, Ancient Greek, Sanskrit, Akkadian, or other dormant ' \
   'languages.'],
  ['masculine', nil, '#6c757d',
   'Grammatically masculine',
   'Assign only for genus, species, or subspecies ranks. A gender stated ' \
   'for the name itself is authoritative. Otherwise, adjectival and ' \
   'participial epithets take the gender of the genus (inferred from the ' \
   'genus name if not recorded), genitive noun epithets the gender of ' \
   'the noun in the genitive (decided from its nominative, with the ' \
   'nominative, genitive, and gender as basis, e.g. *sedimen, -inis, n.*), ' \
   'and nouns in ' \
   'apposition their own gender. A gender not stated for the name itself ' \
   'takes at most medium confidence. In New Latin, salt names in -as, ' \
   '-atis (e.g. *phosphas*, *nitras*, *sulfas*) are masculine.'],
  ['feminine', nil, '#6c757d',
   'Grammatically feminine',
   'Same rules as `masculine`.'],
  ['neuter', nil, '#6c757d',
   'Grammatically neuter',
   'Same rules as `masculine`.'],
  ['gender-uncertain', nil, '#adb5bd',
   'Gender ambiguous or explicitly uncertain',
   'Use only when no gender rule resolves the gender (e.g. an adjectival ' \
   'epithet whose genus name does not reveal its gender, or a genitive ' \
   'noun whose nominative cannot be determined), or when the protologue explicitly notes ' \
   'uncertainty, or when the etymology declares several genders for the ' \
   'name itself (e.g. masc. / fem.). Otherwise, participles and ' \
   'adjectives with forms shared between genders take the gender of the ' \
   'genus and are not gender-uncertain by themselves. Do not use when the etymology states a single gender for ' \
   'the name; an explicit statement is authoritative.']
]

# Terms that never justify a tag on their own: proposals of the tag based
# only on one of them are dropped (see TaggingService.propose). Tags not
# listed here have no exclusions
generic_bases = Tag::GENERIC_BASES
trait_bases = generic_bases + Tag::LIVING_BASES
# Bare diminutive suffixes only (bases are matched whole, so a root with the
# suffix, e.g. microbiellum, is kept)
diminutive_bases = %w[
  ulus ula ulum culus cula culum olus ola olum
  ellus ella ellum illus illa illum
]
tag_excluded_bases = {
  'phenonym' => trait_bases + diminutive_bases,
  'lifestyle' => trait_bases,
  'trait' => trait_bases + diminutive_bases,
  'dimensional' => diminutive_bases,
  'classical' => generic_bases
}

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
  tag.excluded_bases = tag_excluded_bases[slug]&.join("\n")
  tag.save!
end

tag_implication_seeds.each do |slug, implied_slug|
  TagImplication.find_or_create_by!(
    tag: Tag.find_by!(slug: slug), implied_tag: Tag.find_by!(slug: implied_slug)
  )
end

puts "Seeded #{tag_seeds.size} tags and " \
     "#{tag_implication_seeds.size} tag implications"
