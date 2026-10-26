require 'test_helper'

class NameTagsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @name = names(:bacillus)
  end

  test 'pending lists names with proposed tags and all their tags' do
    sign_in(users(:curator))
    name = names(:escherichia_coli)
    NameTag.create!(name: name, tag: tags(:eponym), status_int: 1)

    get pending_name_tags_url

    assert_response :success
    assert_select 'h1 .badge-count', text: '1'
    assert_select 'tbody tr', count: 1
    assert_select 'tbody td a[href=?]', name_path(name)
    assert_select 'a[title=?]', 'accept tag toponym'
    assert_select 'a[title=?]', 'reject tag toponym'
    assert_select 'a[title=?]', 'remove tag eponym'
    assert_select 'tbody td a[href=?]', name_path(names(:escherichia)), count: 0
    assert_select 'tbody td a[href=?]', name_path(names(:bacteria)), count: 0
  end

  test 'pending shows the parsed etymology' do
    sign_in(users(:curator))
    names(:escherichia_coli).update!(etymology_xx_description: 'of the colon')

    get pending_name_tags_url

    assert_select 'tbody td', text: /of the colon/
  end

  test 'accepting from the pending list returns to it' do
    sign_in(users(:curator))
    name_tag = name_tags(:escherichia_coli_toponym)

    patch name_tag_url(name_tag),
          params: { name_tag: { status_int: 1 } },
          headers: { 'HTTP_REFERER' => pending_name_tags_url(page: 1) }

    assert_redirected_to pending_name_tags_url(page: 1)
    assert_predicate(name_tag.reload, :accepted?)
  end

  test 'curator dashboard links to pending tags' do
    sign_in(users(:curator))

    get dashboard_url(tab: :curator)

    assert_response :success
    assert_select 'a[href=?]', pending_name_tags_path,
                  text: /Names with pending tags/
  end

  test 'pending is only visible to curators' do
    get pending_name_tags_url
    assert_redirected_to root_url

    sign_in(users(:contributor))
    get pending_name_tags_url
    assert_redirected_to root_url
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

  test 'curator can tag a validly published name' do
    sign_in(users(:curator))
    name = names(:escherichia)

    assert_predicate(name, :validated?)
    assert_difference('NameTag.count', 1) do
      post name_tags_url, params: {
        name_tag: { name_id: name.id, tag_id: tags(:masculine).id }
      }
    end
    assert_predicate(NameTag.last, :accepted?)
  end

  test 'non-curators can only propose tags under their own username' do
    sign_in(users(:contributor))

    assert_difference('NameTag.count', 1) do
      post name_tags_url, params: {
        name_tag: {
          name_id: names(:draft_by_contributor).id, tag_id: tags(:eponym).id,
          status_int: 1, proposed_by: 'curator'
        }
      }
    end

    name_tag = NameTag.last
    assert_predicate(name_tag, :proposed?)
    assert_equal('contributor', name_tag.proposed_by)
  end

  test 'non-curators cannot tag names they cannot edit' do
    sign_in(users(:contributor))

    assert_predicate(@name, :public?)
    assert_no_difference('NameTag.count') do
      post name_tags_url, params: {
        name_tag: { name_id: @name.id, tag_id: tags(:eponym).id }
      }
    end
    assert_equal('Action not allowed', flash[:alert])
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
