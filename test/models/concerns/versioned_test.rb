require 'test_helper'

class VersionedTest < ActiveSupport::TestCase
  teardown { Current.reset }

  test 'records the current user as the version author' do
    name = names(:escherichia_coli)
    Current.user = users(:curator)
    name.update!(authority: 'Smith')
    Current.reset
    name.update!(authority: 'Jones')

    assert_equal [users(:curator), nil], name.versions.order(:id).last(2).map(&:user)
  end
  test 'resolves retained records directly and when preloading mixed history' do
    name = names(:escherichia_coli)
    link = PublicationName.create!(name: name, publication: publications(:one))
    placement = Placement.create!(name: name, parent: names(:escherichia))
    name.update!(authority: 'Smith')
    versions = [link.versions.last, placement.versions.last, name.versions.last]
    link.soft_delete!
    placement.soft_delete!

    versions.zip([link, placement, name]).each do |version, record|
      assert_equal record, version.reload.record
    end
    preloaded = Version.where(id: versions.map(&:id)).includes(:record).index_by(&:id)
    versions.zip([link, placement, name]).each do |version, record|
      assert_equal record, preloaded.fetch(version.id).record
    end
    assert_not PublicationName.exists?(link.id)
    assert_not Placement.exists?(placement.id)
  end

end
