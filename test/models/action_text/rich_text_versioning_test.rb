require 'test_helper'

class ActionText::RichTextVersioningTest < ActiveSupport::TestCase
  setup do
    @name = Name.create!(name: 'E. coli', rank: 'species', description: 'A gut bacterium')
    @rich_text = @name.rich_text_description
  end

  test 'creating a rich text records its body as HTML' do
    version = @rich_text.versions.first

    assert_equal 'create', version.operation
    assert_nil version.changeset['body'].first
    assert_includes version.changeset['body'].last, 'A gut bacterium'
    assert_equal [nil, 'description'], version.changeset['name']
  end

  test 'editing a rich text records its before and after HTML' do
    assert_difference -> { @rich_text.versions.count } do
      @name.reload.update!(description: 'A commensal gut bacterium')
    end

    changeset = @rich_text.versions.last.changeset
    assert_equal %w[body], changeset.keys
    assert_includes changeset['body'].first, 'A gut bacterium'
    assert_includes changeset['body'].last, 'A commensal gut bacterium'
  end
end
