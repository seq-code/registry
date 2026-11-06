require 'test_helper'

class Name::VersionedTest < ActiveSupport::TestCase
  setup do
    @name = Name.new(name: 'E. coli', rank: 'species')
  end

  teardown { Current.reset }

  test 'creating a name changes all attributes from nothing' do
    assert_difference -> { @name.versions.count } do
      @name.save!
    end

    version = @name.versions.last
    assert_equal 'create', version.operation
    assert_equal @name.attributes.as_json.transform_values { |value| [nil, value] },
                 version.changeset
  end

  test 'updating a name records only changed attributes' do
    @name.save!

    assert_difference -> { @name.versions.count } do
      @name.update!(syllabication: 'co.li')
    end

    version = @name.versions.last
    assert_equal 'update', version.operation
    assert_equal [nil, 'co.li'], version.changeset['syllabication']
    assert_equal %w[syllabication], version.changeset.keys
  end

  test 'records the current user as the version author' do
    Current.user = users(:curator)

    assert_difference -> { @name.versions.count } do
      @name.save!
    end

    assert_equal users(:curator), @name.versions.last.user
  end

  test 'updating only timestamps does not add a version' do
    @name.save!

    assert_no_difference -> { @name.versions.count } do
      @name.update!(created_at: 1.day.ago, updated_at: 1.hour.ago)
    end
  end

  test 'changing an etymology description records the other etymology parts and the name' do
    @name.update!(etymology_xx_lang: 'N.L.', etymology_xx_description: 'of the colon')

    @name.update!(etymology_xx_description: 'from the colon')

    assert_equal({
      'etymology_xx_description' => ['of the colon', 'from the colon'],
      'etymology_xx_lang' => ['N.L.', 'N.L.'],
      'name' => ['E. coli', 'E. coli']
    }, @name.versions.last.changeset)
  end

  test 'changing a polymorphic relationship id records its unchanged record type' do
    @name.nomenclatural_type = strains(:one)
    @name.save!

    @name.update!(nomenclatural_type: strains(:two))

    assert_equal({
      'nomenclatural_type_id' => [strains(:one).id, strains(:two).id],
      'nomenclatural_type_type' => ['Strain', 'Strain']
    }, @name.versions.last.changeset)
  end

  test 'deleting a name changes all final attributes to nothing' do
    @name.save!
    @name.update!(syllabication: 'co.li')
    attributes = @name.attributes.as_json
    versions = Version.where(record: @name)

    assert_difference -> { versions.count } do
      @name.destroy!
    end

    version = versions.last
    assert_equal 'delete', version.operation
    assert_equal attributes.transform_values { |value| [value, nil] }, version.changeset
  end
end
