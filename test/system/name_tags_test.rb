require 'application_system_test_case'

class NameTagsTest < ApplicationSystemTestCase
  test 'selecting a tag applies it without a submit button' do
    name = names(:bacillus)
    sign_in(users(:curator))
    visit name_url(name)

    assert_no_button 'Apply'
    select 'masculine', from: 'name_tag[tag_id]'

    assert_text "for #{name.name}"
    assert NameTag.exists?(name: name, tag: tags(:masculine))
    assert_no_select 'name_tag[tag_id]', with_options: ['masculine']
  end
end
