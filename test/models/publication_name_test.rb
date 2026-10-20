require 'test_helper'

class PublicationNameTest < ActiveSupport::TestCase
  test 'displays the short citation of its publication' do
    publication = publications(:one)
    link = PublicationName.new(name: names(:escherichia_coli), publication: publication)

    assert_equal publication.short_citation, link.display
  end
end
