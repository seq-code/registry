require 'test_helper'

class NameTagsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @name = names(:bacillus)
  end

  test 'curator applies an accepted tag' do
    sign_in(users(:curator))

    assert_difference('NameTag.count', 1) do
      post name_tags_url,
           params: { name_tag: { name_id: @name.id, tag_id: tags(:eponym).id } },
           headers: { 'HTTP_REFERER' => name_url(@name) }
    end

    name_tag = NameTag.last
    assert_redirected_to name_url(@name)
    assert_predicate(name_tag, :accepted?)
    assert_equal('curator', name_tag.proposed_by)
    assert_includes(@name.reload.accepted_tags, tags(:eponym))
  end

  test 'curator can explicitly propose and set proposed_by' do
    sign_in(users(:curator))

    post name_tags_url, params: {
      name_tag: {
        name_id: @name.id, tag_id: tags(:eponym).id,
        status_int: 0, proposed_by: 'llm'
      }
    }

    name_tag = NameTag.last
    assert_predicate(name_tag, :proposed?)
    assert_equal('llm', name_tag.proposed_by)
  end

  test 'non-curators can only propose tags under their own username' do
    sign_in(users(:contributor))

    assert_difference('NameTag.count', 1) do
      post name_tags_url, params: {
        name_tag: {
          name_id: @name.id, tag_id: tags(:eponym).id,
          status_int: 1, proposed_by: 'curator'
        }
      }
    end

    name_tag = NameTag.last
    assert_predicate(name_tag, :proposed?)
    assert_equal('contributor', name_tag.proposed_by)
  end

  test 'non-curators cannot tag names they cannot view' do
    sign_in(users(:contributor))

    assert_no_difference('NameTag.count') do
      post name_tags_url, params: {
        name_tag: { name_id: names(:escherichia_colie).id, tag_id: tags(:eponym).id }
      }
    end
  end

  test 'anonymous users cannot apply tags' do
    assert_no_difference('NameTag.count') do
      post name_tags_url, params: {
        name_tag: { name_id: @name.id, tag_id: tags(:eponym).id }
      }
    end
    assert_redirected_to new_user_session_url
  end

  test 'applying the same tag twice fails gracefully' do
    sign_in(users(:curator))
    name = names(:escherichia)

    assert_no_difference('NameTag.count') do
      post name_tags_url, params: {
        name_tag: { name_id: name.id, tag_id: tags(:eponym).id }
      }
    end
    assert_redirected_to name_url(name)
    assert_not_nil(flash[:danger])
  end

  test 'curator accepts a proposal' do
    sign_in(users(:curator))
    name_tag = name_tags(:escherichia_coli_toponym)

    patch name_tag_url(name_tag), params: { name_tag: { status_int: 1 } }

    assert_redirected_to name_url(name_tag.name)
    assert_predicate(name_tag.reload, :accepted?)
    assert_equal('llm', name_tag.proposed_by)
  end

  test 'curator undoes a rejection' do
    sign_in(users(:curator))
    name_tag = name_tags(:bacteria_eponym)

    patch name_tag_url(name_tag), params: { name_tag: { status_int: 0 } }

    assert_predicate(name_tag.reload, :proposed?)
    assert_includes(names(:bacteria).proposed_tags, tags(:eponym))
  end

  test 'updating only notes keeps the status' do
    sign_in(users(:curator))
    name_tag = name_tags(:escherichia_coli_toponym)

    patch name_tag_url(name_tag), params: { name_tag: { notes: 'Checked' } }

    assert_predicate(name_tag.reload, :proposed?)
    assert_equal('Checked', name_tag.notes)
  end

  test 'non-curators cannot update a tag status' do
    sign_in(users(:contributor))
    name_tag = name_tags(:escherichia_coli_toponym)

    patch name_tag_url(name_tag), params: { name_tag: { status_int: 1 } }

    assert_redirected_to root_url
    assert_predicate(name_tag.reload, :proposed?)
  end

  test 'curator removes a tag' do
    sign_in(users(:curator))
    name_tag = name_tags(:escherichia_eponym)

    assert_difference('NameTag.count', -1) do
      delete name_tag_url(name_tag)
    end
    assert_redirected_to name_url(name_tag.name)
  end

  test 'non-curators cannot remove a tag' do
    sign_in(users(:contributor))

    assert_no_difference('NameTag.count') do
      delete name_tag_url(name_tags(:escherichia_eponym))
    end
  end
end
