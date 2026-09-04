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
