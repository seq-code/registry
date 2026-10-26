require 'test_helper'

class TagsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @tag = tags(:toponym)
  end

  test 'index groups sub-tags under their umbrella' do
    get tags_url

    assert_response :success
    assert_select 'td.pl-5 a', text: 'toponym'
    assert_select 'td:not(.pl-5) a', text: 'geographic'
    assert_select 'a', text: 'Edit', count: 0
  end

  test 'index groups stand-alone tags after the umbrellas' do
    get tags_url

    rows = css_select('tbody tr').map { |tr| tr.text.squish }
    heading = rows.index('Stand-alone')
    assert_not_nil(heading)
    assert_operator(
      rows.index { |r| r.start_with?('masculine') }, :>, heading
    )
    assert_operator(
      rows.index { |r| r.start_with?('toponym') }, :<, heading
    )
    assert_select 'td.pl-5 a', text: 'masculine'
  end

  test 'index shows descriptions instead of slugs' do
    tags(:masculine).update!(description: 'Grammatically masculine')
    get tags_url

    assert_select 'th', text: 'Description'
    assert_select 'th', text: 'Slug', count: 0
    assert_select 'td', text: 'Grammatically masculine'
    assert_select 'td', text: /umbrella/, count: 0
  end

  test 'index and show hide the JSON download buttons' do
    get tags_url
    assert_select 'a[href=?]', tags_url(format: :json), count: 0

    get tag_url(@tag)
    assert_select 'a[href=?]', tag_url(@tag, format: :json), count: 0
  end

  test 'show has a titled definition box' do
    get tag_url(@tag)

    assert_select 'dl.main-section h2', text: /Definition/
    assert_select 'dl.main-section h2 i.float-right'
  end

  test 'index has a new tag curator action for curators only' do
    get tags_url
    assert_select 'dl[name=curator]', count: 0
    assert_select 'a[href=?]', new_tag_url, count: 0

    sign_in(users(:curator))
    get tags_url
    assert_select 'dl[name=curator] a[href=?]', new_tag_url
    assert_select 'a[href=?]', new_tag_path, count: 0
  end

  test 'index links to pending tags for curators only' do
    get tags_url
    assert_select 'a[href=?]', pending_name_tags_url, count: 0

    sign_in(users(:curator))
    get tags_url
    assert_select 'dl[name=curator] a[href=?]', pending_name_tags_url
    assert_select 'dl[name=curator]', text: /tags proposed for 1 name/
  end

  test 'index shows edit links to curators' do
    sign_in(users(:curator))
    get tags_url

    assert_select 'a[href=?]', edit_tag_path(@tag)
  end

  test 'show hides non-public names from anonymous users' do
    get tag_url(@tag)

    assert_response :success
    assert_select 'a[href=?]', name_path(names(:escherichia_colie)), count: 0
    assert_select 'h2', text: /Pending proposals/, count: 0
  end

  test 'show lists all accepted names and pending proposals to curators' do
    sign_in(users(:curator))
    get tag_url(@tag)

    assert_select 'a[href=?]', name_path(names(:escherichia_colie))
    assert_select 'h2', text: /Pending proposals/
    assert_select(
      'a[href=?]',
      name_tag_path(
        name_tags(:escherichia_coli_toponym), name_tag: { status_int: 1 }
      )
    )
  end

  test 'show lists accepted public names' do
    get tag_url(tags(:eponym))

    assert_select 'a[href=?]', name_path(names(:escherichia))
    assert_select 'a[href=?]', name_path(names(:bacteria)), count: 0
  end

  test 'show has crumbs through the umbrella tag' do
    get tag_url(@tag)

    assert_select '.crumbs a[href=?]', tags_url, text: 'Tags'
    assert_select '.crumbs a[href=?]', tag_path(tags(:geographic)),
                  text: 'geographic'
    assert_select '.crumbs span.active', text: 'toponym'
  end

  test 'index and edit have crumbs' do
    get tags_url
    assert_select '.crumbs span.active', text: 'Tags'

    sign_in(users(:curator))
    get edit_tag_url(@tag)
    assert_select '.crumbs a[href=?]', tag_path(@tag), text: 'toponym'
    assert_select '.crumbs span.active', text: 'Edit'
  end

  test 'edit and new forms have a cancel button' do
    sign_in(users(:curator))

    get edit_tag_url(@tag)
    assert_select 'a.btn.btn-secondary[href=?]', tag_path(@tag), text: 'Cancel'
    assert_select 'a', text: 'Back', count: 0

    get new_tag_url
    assert_select 'a.btn.btn-secondary[href=?]', tags_path, text: 'Cancel'
  end

  test 'failed update keeps crumbs with the saved tag name' do
    sign_in(users(:curator))
    patch tag_url(@tag), params: { tag: { name: '' } }

    assert_response :unprocessable_entity
    assert_select '.crumbs a[href=?]', tag_url(@tag), text: 'toponym'
  end

  test 'show lists rejections with undo links to curators only' do
    undo = name_tag_path(
      name_tags(:bacteria_eponym), name_tag: { status_int: 0 }
    )
    get tag_url(tags(:eponym))
    assert_select 'a[href=?]', undo, count: 0

    sign_in(users(:curator))
    get tag_url(tags(:eponym))
    assert_select 'h2', text: /Rejected/
    assert_select 'a[href=?]', undo
  end

  test 'show has curator actions for curators only' do
    get tag_url(@tag)
    assert_select 'dl[name=curator]', count: 0
    assert_select 'a[href=?]', edit_tag_url(@tag), count: 0

    sign_in(users(:curator))
    get tag_url(@tag)
    assert_select 'dl[name=curator] a[href=?]', edit_tag_url(@tag)
    assert_select 'h1 a[href=?]', edit_tag_path(@tag), count: 0
  end

  test 'edit requires a curator' do
    sign_in(users(:contributor))
    get edit_tag_url(@tag)

    assert_redirected_to root_url
  end

  test 'curator creates a sub-tag' do
    sign_in(users(:curator))

    assert_difference('Tag.count', 1) do
      post tags_url, params: {
        tag: {
          name: 'econym', slug: 'econym', color: '#5fa8c4',
          parent_id: tags(:geographic).id,
          description: 'Named after a habitat'
        }
      }
    end

    tag = Tag.find_by(slug: 'econym')
    assert_redirected_to tag_url(tag)
    assert_equal(tags(:geographic), tag.parent)
    assert_equal('Named after a habitat', tag.description.to_plain_text)
  end
end
