require 'test_helper'

class PublicationTest < ActiveSupport::TestCase
  test 'requires a title' do
    p = Publication.new(
      journal_date: Date.new(2020, 1, 1), pub_type: 'journal-article'
    )
    assert_not p.valid?
    assert_includes p.errors[:title], "can't be blank"
  end

  test 'requires a journal_date' do
    p = Publication.new(title: 'A Paper', pub_type: 'journal-article')
    assert_not p.valid?
    assert_includes p.errors[:journal_date], "can't be blank"
  end

  test 'requires a pub_type' do
    p = Publication.new(title: 'A Paper', journal_date: Date.new(2020, 1, 1))
    assert_not p.valid?
    assert_includes p.errors[:pub_type], "can't be blank"
  end

  test 'allows multiple publications without a doi' do
    a = Publication.new(
      title: 'A Paper', journal_date: Date.new(2020, 1, 1),
      pub_type: 'journal-article'
    )
    b = Publication.new(
      title: 'Another Paper', journal_date: Date.new(2021, 1, 1),
      pub_type: 'journal-article'
    )
    assert a.valid?
    assert b.valid?
  end

  test 'rejects a duplicate doi' do
    dup = Publication.new(
      title: 'Duplicate', journal_date: Date.new(2020, 1, 1),
      pub_type: 'journal-article', doi: publications(:one).doi
    )
    assert_not dup.valid?
    assert_includes dup.errors[:doi], 'has already been taken'
  end

  test 'link is nil without a doi' do
    assert_nil publications(:no_doi).link
    assert_equal(
      'https://doi.org/%s' % publications(:one).doi, publications(:one).link
    )
  end

  test 'doi_title falls back to an id-based key without a doi' do
    p = publications(:no_doi)
    assert_equal("id:#{p.id}: #{p.title}", p.doi_title(false))
  end

  test 'by_autocomplete resolves the id-based key back to the publication' do
    p = publications(:no_doi)
    found = Publication.by_autocomplete(p.doi_title(false))
    assert_equal p, found
  end

  test 'by_autocomplete still resolves a plain doi' do
    p = publications(:one)
    found = Publication.by_autocomplete(p.doi_title(false))
    assert_equal p, found
  end

  test 'long_citation omits the DOI clause when doi is blank' do
    p = publications(:no_doi)
    assert_not_includes p.long_citation(:text), 'DOI'
    assert_not_includes p.long_citation(:html), 'DOI'
    assert_not_includes p.long_citation(:wikispecies), 'Doi'
  end

  test 'long_citation includes the DOI clause when doi is present' do
    p = publications(:one)
    assert_includes p.long_citation(:text), "DOI: #{p.doi}"
    assert_includes p.long_citation(:html), "DOI: #{p.doi}"
    assert_includes p.long_citation(:wikispecies), "{{Doi|#{p.doi}}}"
  end
end
