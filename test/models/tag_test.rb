require 'test_helper'

class TagTest < ActiveSupport::TestCase
  test 'requires a slug' do
    tag = Tag.new(name: 'new', color: '#000000')

    assert_not(tag.valid?)
    assert_includes(tag.errors.attribute_names, :slug)
  end

  test 'requires a unique slug' do
    tag = Tag.new(name: 'other', slug: 'eponym', color: '#000000')

    assert_not(tag.valid?)
    assert_includes(tag.errors.attribute_names, :slug)
  end

  test 'only allows lowercase letters, digits, and hyphens in slugs' do
    tag = Tag.new(name: 'new', color: '#000000')

    %w[Eponym fictional_place fictional\ place].each do |slug|
      tag.slug = slug
      assert_not(tag.valid?, "#{slug} should be invalid")
    end
    %w[newtag fictional-place tag-2].each do |slug|
      tag.slug = slug
      assert(tag.valid?, "#{slug} should be valid")
    end
  end

  test 'parent and children' do
    assert_equal(tags(:geographic), tags(:toponym).parent)
    assert_includes(tags(:geographic).children, tags(:toponym))
    assert_predicate(tags(:geographic), :umbrella?)
    assert_predicate(tags(:geographic), :top_level?)
    assert_not_predicate(tags(:toponym), :umbrella?)
    assert_not_predicate(tags(:toponym), :top_level?)
    assert_not_predicate(tags(:masculine), :umbrella?)
    assert_predicate(tags(:masculine), :top_level?)
  end

  test 'parent must be a top-level tag' do
    tag = Tag.new(
      name: 'new', slug: 'new', color: '#000000', parent: tags(:toponym)
    )

    assert_not(tag.valid?)
    assert_includes(tag.errors.attribute_names, :parent)
  end

  test 'cannot be its own parent' do
    tag = tags(:masculine)
    tag.parent = tag

    assert_not(tag.valid?)
    assert_includes(tag.errors.attribute_names, :parent)
  end

  test 'an umbrella cannot be nested under another tag' do
    tag = tags(:geographic)
    tag.parent = tags(:commemorative)

    assert_not(tag.valid?)
    assert_includes(tag.errors.attribute_names, :parent)
  end

  test 'accepted_names only includes accepted name tags' do
    assert_includes(tags(:eponym).accepted_names, names(:escherichia))
    assert_not_includes(tags(:eponym).accepted_names, names(:bacteria))
    assert_includes(tags(:eponym).names, names(:bacteria))
    assert_not_includes(
      tags(:toponym).accepted_names, names(:escherichia_coli)
    )
  end

  test 'destroying a tag orphans its children and removes its name tags' do
    umbrella = tags(:geographic)

    assert_difference('NameTag.count', -2) do
      tags(:toponym).destroy
    end
    assert_difference('Tag.count', -1) do
      tags(:commemorative).destroy
    end
    assert_nil(tags(:eponym).reload.parent)
    assert_predicate(umbrella.reload, :top_level?)
  end
end
