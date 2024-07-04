class Contact < ApplicationRecord
  belongs_to(:publication)
  belongs_to(:user)
  belongs_to(:author)

  validates(:publication, presence: true)
  validates(:user, presence: true)
  validates(:author, presence: true)
  validates(:to, presence: true)
  validates(:cc, presence: true)

  has_rich_text(:message)

  def default_message
    <<~MSG
    Dear author,
    <br/>
    <br/>...
    <br/>We are contacting you with respect to the following manuscript:
    <br/>#{publication.long_citation_html.strip}
    <br/>
    <br/>...
    <br/>
    MSG
  end
end
