require 'test_helper'

class SequencingExperimentTest < ActiveSupport::TestCase
  RUN_XML = <<~XML
    <RUN_SET>
    <RUN accession="SRR11674045">
      <RUN_LINKS>
        <RUN_LINK><XREF_LINK><DB>ENA-SAMPLE</DB><ID>SRS6587259</ID></XREF_LINK></RUN_LINK>
      </RUN_LINKS>
    </RUN>
    </RUN_SET>
  XML

  EXPERIMENT_XML_WITHOUT_BIOSAMPLE = <<~XML
    <EXPERIMENT_SET>
    <EXPERIMENT accession="SRX8234897">
      <DESIGN>
        <SAMPLE_DESCRIPTOR accession="SRS6587259">
          <IDENTIFIERS>
            <PRIMARY_ID>SRS6587259</PRIMARY_ID>
          </IDENTIFIERS>
        </SAMPLE_DESCRIPTOR>
      </DESIGN>
    </EXPERIMENT>
    </EXPERIMENT_SET>
  XML

  EXPERIMENT_XML_WITH_BIOSAMPLE = <<~XML
    <EXPERIMENT_SET>
    <EXPERIMENT accession="SRX0000001">
      <DESIGN>
        <SAMPLE_DESCRIPTOR accession="SRS0000001">
          <IDENTIFIERS>
            <PRIMARY_ID>SRS0000001</PRIMARY_ID>
            <EXTERNAL_ID namespace="BioSample">SAMN00000001</EXTERNAL_ID>
          </IDENTIFIERS>
        </SAMPLE_DESCRIPTOR>
      </DESIGN>
    </EXPERIMENT>
    </EXPERIMENT_SET>
  XML

  SAMPLE_XML = <<~XML
    <SAMPLE_SET>
    <SAMPLE accession="SRS6587259">
      <IDENTIFIERS>
        <PRIMARY_ID>SRS6587259</PRIMARY_ID>
        <EXTERNAL_ID namespace="BioSample">SAMN14825666</EXTERNAL_ID>
      </IDENTIFIERS>
    </SAMPLE>
    </SAMPLE_SET>
  XML

  def stub_requests(responses)
    se = SequencingExperiment.new
    se.define_singleton_method(:external_request) do |uri, *_|
      match = responses.find { |uri_suffix, _| uri.end_with?(uri_suffix) }
      match && match.last
    end
    se
  end

  test 'resolves the true BioSample accession for a RUN whose ENA-SAMPLE link is only an ENA/SRA sample accession' do
    se = stub_requests(
      'SRR11674045' => RUN_XML,
      'SRS6587259' => SAMPLE_XML
    )
    se.sra_accession = 'SRR11674045'
    se.external_sra_to_biosample!

    assert_equal 'SAMN14825666', se.biosample_accession
    assert_equal 'SRS6587259', se.biosample_accession_2
  end

  test 'resolves the true BioSample accession for an EXPERIMENT whose SAMPLE_DESCRIPTOR omits it' do
    se = stub_requests(
      'SRX8234897' => EXPERIMENT_XML_WITHOUT_BIOSAMPLE,
      'SRS6587259' => SAMPLE_XML
    )
    se.sra_accession = 'SRX8234897'
    se.external_sra_to_biosample!

    assert_equal 'SAMN14825666', se.biosample_accession
    assert_equal 'SRS6587259', se.biosample_accession_2
  end

  test 'uses the BioSample accession directly when the EXPERIMENT already embeds it' do
    se = stub_requests('SRX0000001' => EXPERIMENT_XML_WITH_BIOSAMPLE)
    se.sra_accession = 'SRX0000001'
    se.external_sra_to_biosample!

    assert_equal 'SAMN00000001', se.biosample_accession
    assert_equal 'SRS0000001', se.biosample_accession_2
  end

  test 'falls back to the ENA/SRA sample accession when BioSample resolution fails' do
    se = stub_requests(
      'SRR11674045' => RUN_XML
      # no response stubbed for the SRS6587259 sample lookup -> resolution fails
    )
    se.sra_accession = 'SRR11674045'
    se.external_sra_to_biosample!

    assert_equal 'SRS6587259', se.biosample_accession
    assert_nil se.biosample_accession_2
  end
end
