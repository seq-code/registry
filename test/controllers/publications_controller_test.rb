require 'test_helper'

class PublicationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @publication = publications(:one)
  end

  test 'curator sees the manual-entry form with an 1900-based year range' do
    sign_in(users(:curator))

    get(new_publication_url)

    assert_response :success
    assert_includes @response.body, 'Authors (given name, family name)'
    assert_select(
      'select#publication_journal_date_1i option[value="1900"]'
    )
  end

  test 'manual-entry section is collapsed by default' do
    sign_in(users(:curator))

    get(new_publication_url)

    assert_response :success
    assert_select('#manual-entry-section.d-none')
  end

  test 'manual-entry section re-expands after a failed manual submission' do
    sign_in(users(:curator))

    post(
      publications_url,
      params: {
        publication: {
          doi: '', title: '', journal: 'Journal of Examples',
          journal_date: Date.new(1978, 6, 1), pub_type: 'journal-article'
        }
      }
    )

    assert_response :success
    assert_select('#manual-entry-section:not(.d-none)')
  end

  test 'curator can register a publication without a doi' do
    sign_in(users(:curator))

    assert_difference('Publication.count', 1) do
      post(
        publications_url,
        params: {
          publication: {
            doi: '', title: 'A Manually Entered Paper',
            journal: 'Journal of Examples',
            journal_date: Date.new(1978, 6, 1), pub_type: 'journal-article'
          }
        }
      )
    end

    publication = Publication.find_by(title: 'A Manually Entered Paper')
    assert_not_nil publication
    assert_nil publication.doi
    assert_redirected_to publication
  end

  test 'curator can register a publication with manually entered authors' do
    sign_in(users(:curator))

    post(
      publications_url,
      params: {
        publication: {
          doi: '', title: 'A Multi-Author Paper',
          journal: 'Journal of Examples',
          journal_date: Date.new(1978, 6, 1), pub_type: 'journal-article'
        },
        authors_given: ['J.', 'A.'],
        authors_family: ['Doe', 'Smith']
      }
    )

    publication = Publication.find_by(title: 'A Multi-Author Paper')
    assert_not_nil publication
    assert_equal ['Doe', 'Smith'], publication.authors.pluck(:family)
  end

  test 'authors survive a re-render after a validation error' do
    sign_in(users(:curator))

    assert_no_difference('Publication.count') do
      post(
        publications_url,
        params: {
          publication: {
            doi: '', title: '', journal: 'Journal of Examples',
            journal_date: Date.new(1978, 6, 1), pub_type: 'journal-article'
          },
          authors_given: ['J.', 'A.'],
          authors_family: ['Doe', 'Smith']
        }
      )
    end

    assert_response :success
    assert_select('input[name="authors_given[]"][value="J."]')
    assert_select('input[name="authors_family[]"][value="Doe"]')
    assert_select('input[name="authors_given[]"][value="A."]')
    assert_select('input[name="authors_family[]"][value="Smith"]')
  end

  test 'curator can link an existing doi-less publication to a name' do
    sign_in(users(:curator))
    name = names(:bacillus_subtilis)
    publication = publications(:no_doi)

    assert_no_difference('Publication.count') do
      post(
        publications_url,
        params: {
          publication: { doi: publication.doi_title(false) },
          link_name: { id: name.id, as: 'cite' }
        }
      )
    end

    assert_includes(name.reload.publications, publication)
    assert_redirected_to(name)
  end

  test 'non-curator can also link an existing doi-less publication to a name' do
    sign_in(users(:contributor))
    name = names(:bacillus_subtilis)
    publication = publications(:no_doi)

    post(
      publications_url,
      params: {
        publication: { doi: publication.doi_title(false) },
        link_name: { id: name.id, as: 'cite' }
      }
    )

    assert_includes(name.reload.publications, publication)
  end

  test 'non-curator cannot register a publication without a doi' do
    sign_in(users(:contributor))

    assert_no_difference('Publication.count') do
      post(
        publications_url,
        params: {
          publication: {
            doi: '', title: 'A Manually Entered Paper',
            journal: 'Journal of Examples',
            journal_date: Date.new(1978, 6, 1), pub_type: 'journal-article'
          }
        }
      )
    end

    assert_response :success
    assert_includes @response.body, 'New Publication'
  end
end
