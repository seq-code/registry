require 'test_helper'

class NameTagTest < ActiveSupport::TestCase
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

  test 'destroying a name removes its name tags' do
    assert_difference('NameTag.count', -1) do
      names(:bacteria).destroy
    end
  end
end
