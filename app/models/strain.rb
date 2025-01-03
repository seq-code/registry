class Strain < ApplicationRecord
  has_many(
    :typified_names, class_name: 'Name',
    as: :nomenclatural_type, dependent: :nullify
  )
  has_many(:genomes, dependent: :nullify)

  validates(:numbers_string, presence: true)

  before_save(:clean_numbers)

  include HasExternalResources
  include Strain::ExternalResources

  class << self
    ##
    # Hash of culture collection prefixes and URL rule.
    # See also: https://ftp.ncbi.nih.gov/pub/taxonomy/Ccode_dump.txt
    # See also: https://jcm.brc.riken.jp/en/abbr_e
    def culture_collections
      {
        ATCC: 'https://www.atcc.org/products/%s',
        DSM:  'https://www.dsmz.de/collection/catalogue/details/culture/DSM-%s',
        IFO:  'https://www.nite.go.jp/nbrc/catalogue/' \
              'NBRCCatalogueDetailServlet?ID=IFO&CAT=%s',
        JCM:  'https://www.jcm.riken.jp/cgi-bin/jcm/jcm_number?JCM=%s',
        KCTC: 'https://kctc.kribb.re.kr/collection/view?sn=%s',
        NBRC: 'https://www.nite.go.jp/nbrc/catalogue/' \
              'NBRCCatalogueDetailServlet?ID=IFO&CAT=%s',
        NCTC: 'https://www.culturecollections.org.uk/products/bacteria/' \
              'detail.jsp?collection=nctc&refId=NCTC+%s',

        # Bioresource Collection and Research Center
        # [TW: Food Industry Research and Development Insitute]
        BCRC: 'https://catalog.bcrc.firdi.org.tw/BcrcContent?bid=%s',
        # Collection of Aquatic Important Microorganisms
        # [MX: CIAD, Centro de Investigación en Alimentación y Desarrollo]
        CAIM: 'https://www.ciad.mx/caim/busqueda.php?' \
              'searchtype=caim&criterio=%s',
        # Culture Collection of Autotrophic Organisms
        # [CZ: Czech Academy of Sciences]
        CCALA: 'https://ccala.butbn.cas.cz/strain/%s',
        # Czech Collection of Microorganisms
        # [CZ: Masaryk University]
        CCM: 'https://www.sci.muni.cz/ccm/bakterie/camb/%s',
        # China General Microbiological Culture Collection Center
        # [CN: National Science and Technology Infrastructure]
        # -- From NCBI Taxonomy (not working):
        # -- 'http://www.cgmcc.net/english/cata.php?stn=CGMCC%%20%s'
        CGMCC: 'https://cgmcc.net/english/search?stn=%s',
        # NCMA, National Center for Marine Algae and Microbiota,
        # formerly Culture Collection for Marine Phytoplankton
        # [US: Bigelow Laboratory for Ocean Sciences]
        CCMP: 'https://ncma.bigelow.org/CCMP%s',
        # Culture Collection University of Gothenburg
        # [SE: University of Gothenburg]
        CCUG: 'https://www.ccug.se/strain?id=%s',
        # China Center of Industrial Culture Collection
        # [CN: China National Research Institute of Food & Fermentation
        # Industries]
        CICC: 'http://www.china-cicc.org/search/?classtype=1&keyword=%s',
        # Collection de l'Institut Pasteur
        # (Collection of the Institut Pasteur)
        # [FR: Institut Pasteur]
        CIP:  'https://catalogue-crbip.pasteur.fr/' \
              'fiche_catalogue.xhtml?crbip=CIP%%20%s',
        # BCCM, Belgian Coordinated Collections of Microorganisms /
        # Institute of Tropical Medicine Antwerp Mycobacteria Collection
        # [BE: Belgian Science Policy (BELSPO)]
        ITM:  'https://bccm.belspo.be/catalogues/bm-details?' \
              'accession_number=ITM%%20%s',
        # Jena Microbial Resource Collection
        # [DE: Friedrich Schiller University Jena]
        JMRC: 'http://www.jmrc.uni-jena.de/data.php?fsu=%s',
        # Korean Agricultural Culture Collection
        # [KR: National Academy of Agricultural Science]
        KACC: 'https://genebank.rda.go.kr/eng/mic/cat/MicrobeSearch.do' \
              '?sSearchWith=no&sTxt1=%s',
        # BCCM, Belgian Coordinated Collections of Microorganisms /
        # Bacteria Collection Laboratorium voor Microbiologie Universiteit Gent
        # (Bacteria Collection Laboratory of Microbiology, University of Ghent)
        # [BE: Belgian Science Policy (BELSPO)]
        LMG:  'https://bccm.belspo.be/catalogues/lmg-strain-details?NUM=%s',
        # Marine Culture Collection of China
        # [CN: Third Institute of Oceanography]
        MCCC: 'https://mccc.org.cn/detailRecord3.asp?bcbh=%s',
        # North East Pacific Culture Collection
        # [CA: The University of British Columbia]
        NEPCC: 'https://db.botany.ubc.ca/cccm/mfa/%s',
        # National Institute for Environmental Studies Collection
        # [JP: National Institute for Environmental Studies]
        NIES: 'https://mcc.nies.go.jp/numberSearch.do?strainNumber=%s',
        # Agricultural Research Service Culture Collection,
        # formerly Northern Regional Research Laboratory
        # [US: National Center for Agricultural Utilization Research]
        NRRL: 'https://nrrl.ncaur.usda.gov/cgi-bin/usda/prokaryote/' \
              'report.html?nrrlcodes=%s',
        # Pasteur Cultures of Cyanobacteria
        # [FR: Institut Pasteur]
        PCC:  'https://catalogue-crbip.pasteur.fr/' \
              'fiche_catalogue.xhtml?crbip=PCC%%20%s',
        # Sammlung von Algenkulturen
        # (Culture Collection of Algae)
        # [DE: University of Göttingen]
        SAG: 'https://sagdb.uni-goettingen.de/detailedList.php?str_number=%s',
        # Thailand Bioresource Research Center
        # [TH: Thailand Bioresource Research Center]
        TBRC: 'https://tbrcnetwork.org/microb_detail.php?code=TBRC_%s',
        # BCCM, Belgian Coordinated Collections of Microorganisms /
        # University of of Liège Cyanobacteria Collection
        # [BE: Belgian Science Policy (BELSPO)]
        ULC:  'https://bccm.belspo.be/catalogues/bm-details?' \
              'accession_number=ULC%%20%s',
        # ВСЕРОССИЙСКАЯ КОЛЛЕКЦИЯ МИКРООРГАНИЗМОВ
        # (All-Russian Collection of Microorganisms)
        # [RU: Pushchino Scientific Center for Biological Research of the
        # Russian Academy of Sciences]
        VKM: 'http://www.vkm.ru/strains.php?vkm=%s'
      }
    end
  end

  def numbers
    numbers_string.split(' = ')
  end

  def numbers_parsed
    numbers.map do |str|
      parts = str.split(/[ :-]+/, 2)
      coll = parts.count == 2 ? parts[0].upcase.to_sym : nil

      if url_base = self.class.culture_collections[coll]
        {
          collection: coll,
          accession: parts.join(' '),
          url: url_base % parts[1]
        }
      else
        str
      end
    end
  end

  def collections
    numbers_parsed
      .map { |i| i.is_a?(Hash) ? i[:collection] : nil }
      .compact.uniq
  end

  def type_of_type
    'Strain'
  end

  def display(_html = true)
    "#{type_of_type}: #{numbers_string}"
  end

  def old_type_definition
    ['strain', numbers_string]
  end

  def title(prefix = nil)
    prefix ||= 'Strain '
    '%ssc|%07i' % [prefix, id]
  end

  def seqcode_url(protocol = true)
    "#{'https://' if protocol}seqco.de/s:#{id}"
  end

  def uri
    seqcode_url
  end

  def referenced_names
    @names ||= genomes.map(&:typified_names).flatten.compact.uniq
  end

  def names
    typified_names + referenced_names
  end

  def can_edit?(user)
    return false unless user
    return true if user.curator?
    return true unless typified_names.present?
    typified_names.all? { |name| name.can_edit?(user) }
  end

  private

  def clean_numbers
    self.numbers_string =
      numbers_string.strip.gsub(/ +/, ' ').gsub(/ *= */, ' = ')
  end
end
