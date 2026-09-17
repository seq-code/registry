require 'test_helper'

class Name::VersionedTest < ActiveSupport::TestCase
  setup do
    @name = Name.new(name: 'E. coli', rank: 'species')
  end

  test 'creating a name records an empty changeset' do
    assert_difference -> { @name.versions.count } do
      @name.save!
    end

    version = @name.versions.last
    assert_equal 'create', version.operation
    assert_empty version.changeset
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

  test 'updating only timestamps does not add a version' do
    @name.save!

    assert_no_difference -> { @name.versions.count } do
      @name.update!(created_at: 1.day.ago, updated_at: 1.hour.ago)
    end
  end

  test 'saving an unchanged name does not add a version' do
    @name.save!

    assert_no_difference -> { @name.versions.count } do
      @name.save!
    end
  end

  test 'deleting a name records an empty changeset' do
    @name.save!
    versions = Version.where(record: @name)

    assert_difference -> { versions.count } do
      @name.destroy!
    end

    version = versions.last
    assert_equal 'delete', version.operation
    assert_empty version.changeset
  end

  test 'deleting a name retains its history' do
    @name.save!
    version = @name.versions.last

    @name.destroy!

    assert Version.exists?(version.id)
  end

  test 'versions roll back with the name' do
    assert_no_difference -> { Version.count } do
      Name.transaction do
        @name.save!
        raise ActiveRecord::Rollback
      end
    end
  end
end
