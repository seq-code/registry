require 'test_helper'
require Rails.root.join('db/migrate/20261005100000_create_name_history_events')

class NameHistoryEventTest < ActiveSupport::TestCase
  test 'migration preserves public name versions with their timestamps and etymology context' do
    name = names(:escherichia_coli)
    version = Version.create!(
      record: name, operation: 'update', created_at: 1.day.ago,
      changeset: {
        'authority' => [nil, 'Smith'],
        'name' => [name.name, name.name],
        'etymology_xx_lang' => ['N.L.', 'N.L.'],
        'etymology_xx_description' => ['of the colon', 'from the colon'],
        'wikispecies_checked_at' => [nil, Time.current]
      }
    )
    Version.create!(record: name, operation: 'create', changeset: {})
    Version.create!(record: name, operation: 'update',
                    changeset: { 'wikispecies_checked_at' => [nil, Time.current] })

    ActiveRecord::Migration.suppress_messages do
      migration = CreateNameHistoryEvents.new
      migration.migrate(:down)
      migration.migrate(:up)
    end

    assert_equal 1, name.history_events.count
    event = name.history_events.last
    assert_equal 'attributes_changed', event.kind
    assert_equal version.created_at, event.created_at
    assert_equal version.changeset.except('wikispecies_checked_at'), event.data
  end
end
