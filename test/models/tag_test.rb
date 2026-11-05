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

  # Tags for Tag.expand: mythonym (under commemorative) implies mythological,
  # and chrononym is under dimensional
  def create_expansion_tags
    mythological = Tag.create!(name: 'mythological', slug: 'mythological',
                               color: '#000000')
    mythonym = Tag.create!(name: 'mythonym', slug: 'mythonym',
                           color: '#000000', parent: tags(:commemorative))
    mythonym.implied_tags << mythological
    dimensional = Tag.create!(name: 'dimensional', slug: 'dimensional',
                              color: '#000000')
    Tag.create!(name: 'chrononym', slug: 'chrononym', color: '#000000',
                parent: dimensional)
  end

  def expanded(proposals)
    Tag.expand(proposals).to_h { |p| [p['slug'], p] }
  end

  test 'all_implied_tags includes the parent and implied tags' do
    create_expansion_tags

    assert_equal(
      %w[commemorative mythological],
      Tag.find_by(slug: 'mythonym').all_implied_tags.map(&:slug)
    )
    assert_empty(tags(:geographic).all_implied_tags)
  end

  test 'a tag cannot imply itself' do
    implication = TagImplication.new(tag: tags(:eponym),
                                     implied_tag: tags(:eponym))

    assert_not(implication.valid?)
    assert_includes(implication.errors.attribute_names, :implied_tag)
  end

  test 'expand adds the parent of a sub-tag' do
    result = expanded([{ 'slug' => 'eponym', 'confidence' => 'high' }])

    assert_equal(%w[eponym commemorative], result.keys)
    assert_equal(
      { 'slug' => 'commemorative', 'confidence' => 'high',
        'implied_by' => %w[eponym] },
      result['commemorative']
    )
    assert_nil(result['eponym']['implied_by'])
  end

  test 'expand adds both the parent and the implied tags of mythonym' do
    create_expansion_tags
    result = expanded([{ 'slug' => 'mythonym', 'confidence' => 'medium' }])

    assert_equal(%w[mythonym commemorative mythological], result.keys)
    assert_equal('medium', result['commemorative']['confidence'])
    assert_equal('medium', result['mythological']['confidence'])
    assert_equal(%w[mythonym], result['mythological']['implied_by'])
  end

  test 'expand raises an umbrella to the confidence of its child' do
    result = expanded([
      { 'slug' => 'commemorative', 'confidence' => 'low' },
      { 'slug' => 'eponym', 'confidence' => 'high' }
    ])

    assert_equal('high', result['commemorative']['confidence'])
    assert_equal(%w[eponym], result['commemorative']['implied_by'])
  end

  test 'expand never lowers the confidence of an umbrella' do
    result = expanded([
      { 'slug' => 'commemorative', 'confidence' => 'high' },
      { 'slug' => 'eponym', 'confidence' => 'low' }
    ])

    assert_equal('high', result['commemorative']['confidence'])
    assert_equal('low', result['eponym']['confidence'])
  end

  test 'expand normalizes unknown confidences to low' do
    result = expanded([
      { 'slug' => 'masculine', 'confidence' => 'certain' },
      { 'slug' => 'eponym', 'confidence' => nil }
    ])

    assert_equal('low', result['masculine']['confidence'])
    assert_equal('low', result['eponym']['confidence'])
    assert_equal('low', result['commemorative']['confidence'])
  end

  test 'expand adds dimensional for its sub-tags' do
    create_expansion_tags
    result = expanded([{ 'slug' => 'chrononym', 'confidence' => 'high' }])

    assert_equal(%w[chrononym dimensional], result.keys)
    assert_equal(%w[chrononym], result['dimensional']['implied_by'])
  end
end
