require 'test_helper'

class Name::HistoryTest < ActiveSupport::TestCase
  test 'attribute events contain public changes only' do
    name = names(:escherichia_coli)
    name.update!(syllabication: 'co.li', wikispecies_checked_at: Time.current)

    event = name.history_events.last
    assert_equal 'attributes_changed', event.kind
    assert_equal({ 'syllabication' => [nil, 'co.li'] }, event.data)
  end

  test 'etymology events retain context through later etymology and name changes' do
    name = names(:escherichia_coli)
    name.update!(etymology_xx_lang: 'N.L.', etymology_xx_description: 'of the colon')
    name.update!(etymology_xx_description: 'from the colon')
    event = name.history_events.last
    name.update!(name: 'Escherichia fergusonii', etymology_xx_description: 'of Ferguson')

    assert_equal ['N.L.', 'N.L.'], event.data['etymology_xx_lang']
    assert_equal ['Escherichia coli', 'Escherichia coli'], event.data['name']
    assert_equal ['of the colon', 'from the colon'], event.data['etymology_xx_description']
    changes = Name::PublicHistory.new(name.reload).changes_for(event.reload)
    assert_equal %w[etymology], changes.keys
    assert_equal ['N.L. coli, of the colon', 'N.L. coli, from the colon'],
                 changes['etymology'].map { |attributes| Name.new(attributes).full_etymology }
  end

  test 'timestamp and external-resource changes do not create history events' do
    name = names(:escherichia_coli)

    assert_no_difference -> { name.history_events.count } do
      name.update!(updated_at: 1.hour.ago, wikispecies_checked_at: Time.current)
    end
  end

  test 'a failed name update leaves no public history event' do
    name = names(:escherichia_coli)

    assert_no_difference -> { name.history_events.count } do
      assert_not name.update(authority: 'Smith', syllabication: 'co li')
    end
  end
end
