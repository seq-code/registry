require 'test_helper'

class NameTagTest < ActiveSupport::TestCase
  # Tags for the implication cascade: eponym, institutonym, and mythonym are
  # under commemorative, and mythonym also implies mythological
  setup do
    @name = names(:bacillus)
    Tag.create!(name: 'institutonym', slug: 'institutonym', color: '#000000',
                parent: tags(:commemorative))
    mythological = Tag.create!(name: 'mythological', slug: 'mythological',
                               color: '#000000')
    mythonym = Tag.create!(name: 'mythonym', slug: 'mythonym',
                           color: '#000000', parent: tags(:commemorative))
    mythonym.implied_tags << mythological
  end

  # Create the NameTag of +slug+ on @name with +attributes+
  def tag_name(slug, status_int, **attributes)
    NameTag.create!(
      name: @name, tag: Tag.find_by!(slug: slug), status_int: status_int,
      proposed_by: 'curator', **attributes
    )
  end

  def name_tag(slug)
    NameTag.find_by(name: @name, tag: Tag.find_by!(slug: slug))
  end

  test 'does not allow the same tag to be applied twice to the same name' do
    name_tag = NameTag.new(name: names(:escherichia), tag: tags(:eponym))

    assert_not(name_tag.valid?)
    assert_includes(name_tag.errors.attribute_names, :name_id)
  end

  test 'allows the same tag on different names' do
    name_tag = NameTag.new(name: names(:bacillus), tag: tags(:eponym))

    assert(name_tag.valid?)
  end

  test 'defaults to proposed' do
    name_tag = NameTag.new(name: names(:bacillus), tag: tags(:eponym))

    assert_predicate(name_tag, :proposed?)
    assert_equal(:proposed, name_tag.status)
  end

  test 'only allows known statuses' do
    name_tag = NameTag.new(
      name: names(:bacillus), tag: tags(:eponym), status_int: 3
    )

    assert_not(name_tag.valid?)
    assert_includes(name_tag.errors.attribute_names, :status_int)
  end

  test 'status predicates' do
    assert_predicate(name_tags(:escherichia_eponym), :accepted?)
    assert_equal(:accepted, name_tags(:escherichia_eponym).status)
    assert_predicate(name_tags(:escherichia_coli_toponym), :proposed?)
    assert_predicate(name_tags(:bacteria_eponym), :rejected?)
    assert_equal(:rejected, name_tags(:bacteria_eponym).status)
  end

  test 'name.accepted_tags and name.proposed_tags filter by status' do
    assert_includes(names(:escherichia).accepted_tags, tags(:eponym))
    assert_includes(names(:escherichia_coli).proposed_tags, tags(:toponym))
    assert_empty(names(:escherichia_coli).accepted_tags)
    assert_empty(names(:bacteria).accepted_tags)
    assert_empty(names(:bacteria).proposed_tags)
    assert_includes(names(:bacteria).tags, tags(:eponym))
  end

  test 'confidence is read from notes' do
    name_tag = name_tags(:escherichia_coli_toponym)
    assert_nil(name_tag.confidence)

    name_tag.notes = 'confidence: low'
    assert_equal('low', name_tag.confidence)

    name_tag.notes = 'confidence: medium; implied by: eponym'
    assert_equal('medium', name_tag.confidence)

    name_tag.notes = 'confidence: high; also implied by: econym, toponym'
    assert_equal('high', name_tag.confidence)

    name_tag.notes =
      'confidence: high; basis: Svalbard; also implied by: toponym'
    assert_equal('high', name_tag.confidence)

    name_tag.notes = 'confidence: medium; basis: camponoti; capped from high'
    assert_equal('medium', name_tag.confidence)
  end

  test 'accepting a tag creates its accepted umbrella' do
    tag_name('eponym', 1, actor: 'alice')
    umbrella = name_tag('commemorative')

    assert_predicate(umbrella, :accepted?)
    assert_equal(-1, umbrella.pre_cascade_status_int)
    assert_equal('alice', umbrella.proposed_by)
    assert_equal('accepted via eponym', umbrella.notes)
  end

  test 'cascade-created tags fall back to the proposer without an actor' do
    tag_name('eponym', 1, proposed_by: 'bob')

    assert_equal('bob', name_tag('commemorative').proposed_by)
  end

  test 'accepting a tag accepts its proposed umbrella' do
    tag_name('commemorative', 0, notes: 'confidence: high')
    eponym = tag_name('eponym', 0, skip_implication_cascade: true)
    eponym.update!(status_int: 1)
    umbrella = name_tag('commemorative')

    assert_predicate(umbrella, :accepted?)
    assert_equal(0, umbrella.pre_cascade_status_int)
    assert_equal('confidence: high; accepted via eponym', umbrella.notes)
    assert_equal('high', umbrella.confidence)
  end

  test 'accepting a tag accepts its rejected umbrella' do
    tag_name('commemorative', 2)
    tag_name('eponym', 1)
    umbrella = name_tag('commemorative')

    assert_predicate(umbrella, :accepted?)
    assert_equal(2, umbrella.pre_cascade_status_int)
    assert_equal('was rejected; accepted via eponym', umbrella.notes)
  end

  test 'accepting a tag accepts its parent and its implied tags' do
    tag_name('mythonym', 1)

    assert_predicate(name_tag('commemorative'), :accepted?)
    assert_predicate(name_tag('mythological'), :accepted?)
  end

  test 'accepting a tag leaves already accepted implied tags unchanged' do
    tag_name('commemorative', 1, notes: 'by hand')
    tag_name('eponym', 1)
    umbrella = name_tag('commemorative')

    assert_nil(umbrella.pre_cascade_status_int)
    assert_equal('by hand', umbrella.notes)
  end

  test 'undoing an acceptance destroys cascade-created tags' do
    eponym = tag_name('eponym', 1)
    eponym.update!(status_int: 2)

    assert_nil(name_tag('commemorative'))
  end

  test 'destroying an accepted tag destroys cascade-created tags' do
    tag_name('eponym', 1).destroy!

    assert_nil(name_tag('commemorative'))
  end

  test 'undoing an acceptance restores a proposed implied tag' do
    tag_name('commemorative', 0, notes: 'confidence: low')
    tag_name('eponym', 1).update!(status_int: 2)
    umbrella = name_tag('commemorative')

    assert_predicate(umbrella, :proposed?)
    assert_nil(umbrella.pre_cascade_status_int)
    assert_equal(
      'confidence: low; accepted via eponym; ' \
      'reverted: eponym no longer accepted',
      umbrella.notes
    )
    assert_equal('low', umbrella.confidence)
  end

  test 'undoing an acceptance restores a rejected implied tag' do
    tag_name('commemorative', 2)
    tag_name('eponym', 1).update!(status_int: 2)
    umbrella = name_tag('commemorative')

    assert_predicate(umbrella, :rejected?)
    assert_nil(umbrella.pre_cascade_status_int)
    assert_match(/reverted: eponym no longer accepted\z/, umbrella.notes)
  end

  test 'undoing an acceptance keeps tags still implied by another' do
    eponym = tag_name('eponym', 1)
    tag_name('institutonym', 1)
    eponym.update!(status_int: 2)
    umbrella = name_tag('commemorative')

    assert_predicate(umbrella, :accepted?)
    assert_equal(-1, umbrella.pre_cascade_status_int)
  end

  test 'a directly re-accepted tag is no longer auto-accepted' do
    eponym = tag_name('eponym', 1)
    name_tag('commemorative').update!(status_int: 1)
    assert_nil(name_tag('commemorative').pre_cascade_status_int)

    eponym.update!(status_int: 2)
    assert_predicate(name_tag('commemorative'), :accepted?)
  end

  test 'proposing a tag proposes its missing implied tags' do
    tag_name('eponym', 0, proposed_by: 'alice')
    umbrella = name_tag('commemorative')

    assert_predicate(umbrella, :proposed?)
    assert_equal('alice', umbrella.proposed_by)
    assert_equal('implied by eponym', umbrella.notes)
    assert_nil(umbrella.pre_cascade_status_int)
  end

  test 'proposing a tag does not touch existing implied tags' do
    tag_name('commemorative', 2, notes: 'no')
    tag_name('eponym', 0)
    umbrella = name_tag('commemorative')

    assert_predicate(umbrella, :rejected?)
    assert_equal('no', umbrella.notes)
  end

  test 'proposing a tag can skip the implication cascade' do
    tag_name('mythonym', 0, skip_implication_cascade: true)

    assert_nil(name_tag('commemorative'))
    assert_nil(name_tag('mythological'))
  end

  test 'confidence is read from notes with cascade additions' do
    name_tag = NameTag.new(
      notes: 'confidence: medium; basis: Svalbard; was rejected; ' \
             'accepted via eponym; reverted: eponym no longer accepted'
    )

    assert_equal('medium', name_tag.confidence)
  end

  test 'destroying a name removes its name tags' do
    assert_difference('NameTag.count', -1) do
      names(:bacteria).destroy
    end
  end
end
