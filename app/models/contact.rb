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

  after_create(:send_message)

  def default_message
    <<~MSG
    Dear author,
    <br/>
    <br/>I have seen with interest your article:
    <br/>#{publication.long_citation_html.strip}
    <br/>
    <br/>As you have proposed <i>Candidatus</i> names for the taxa represented
    by the MAGs you described, it might interest you to know that these names
    could be validly published under the SeqCode, a nomenclatural code for
    prokaryotes described from sequence data (please see
    <i>Nature Microbiology</i>
    <a href="https://doi.org/10.1038/s41564-022-01214-9">DOI: 10.1038/s41564-022-01214-9</a>).
    <br/>
    <br/>Names are validly published under the SeqCode by registration in the
    SeqCode registry
    (<a href="https://registry.seqco.de/">https://registry.seqco.de/</a>), with
    details of the effective publication (your paper) and the MAGs that are the
    type genome. More details on this are available in the article <i>mLife</i>,
    <a href="https://doi.org/10.1002/mlf2.12092">DOI: 10.1002/mlf2.12092</a>
    and at the Registry website.
    <br/>
    <br/>It is a limitation of <i>Candidatus</i> names that they lack formal
    standing in nomenclature. Therefore, we hope that you will consider validly
    publishing the names in your paper under the SeqCode.
    <br/>
    <br/>With best wishes,
    <br/>#{user&.informal_name}
    MSG
  end

  private

    def send_message
      # Send email notification
      ExternalMailer.with(
        reply_to: user.email,
        to: to,
        cc: cc,
        subject: subject
      ).simple_email(message).deliver_later
    end
end
