require 'application_system_test_case'

class NameHistoryTest < ApplicationSystemTestCase
  test 'the history button opens the event timeline with text diffs and publication links' do
    name = names(:escherichia_coli)
    publication = publications(:one)
    name.update!(authority: 'Smith', etymology_xx_lang: 'N.L.',
                 etymology_xx_description: 'of the colon')
    name.update!(authority: 'Smith and Jones', etymology_xx_description: 'from the colon')
    link = PublicationName.create!(name: name, publication: publication)
    link.destroy!

    visit name_url(name)
    click_link 'History'

    assert_current_path history_name_path(name)
    assert_selector '.name-history-event', count: 4
    assert_selector '.name-history-before del', text: 'of'
    assert_selector '.name-history-after ins', text: 'from'
    assert_selector 'th[scope=row]', text: 'Pub linked'
    assert_selector 'th[scope=row]', text: 'Pub unlinked'
    assert_selector ".name-history-before a[href='#{publication_path(publication)}']",
                    text: publication.short_citation
    assert_selector ".name-history-after a[href='#{publication_path(publication)}']",
                    text: publication.short_citation
  end
end
