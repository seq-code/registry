# A term of the SeqCode Committee, defined in config/committee/<start year>.yml,
# with the people (shared across terms) in config/committee/people.yml
#
# Terms last four years and line up with the community membership cohorts
# (see User::FIRST_COMMUNITY_MEMBERSHIP_COHORT_END)
class CommitteeTerm
  DIR = Rails.root.join('config', 'committee')
  LENGTH = 4

  class << self
    def first_start_year
      User::FIRST_COMMUNITY_MEMBERSHIP_COHORT_END.year - LENGTH + 1
    end

    # Start year of the term in office on +date+, whether defined or not
    def start_year_for(date = Date.current)
      first_start_year +
        ((date.year - first_start_year) / LENGTH) * LENGTH
    end

    # Start years of all defined terms, including upcoming ones
    def years
      Dir[DIR.join('[0-9][0-9][0-9][0-9].yml')]
        .map { |file| File.basename(file, '.yml').to_i }.sort
    end

    def find(year)
      unless year.to_s =~ /\A\d{4}\z/ && years.include?(year.to_i)
        raise(ActiveRecord::RecordNotFound, "Unknown committee term: #{year}")
      end

      new(year.to_i)
    end

    # The term in office on +date+, or the latest past one if the term in
    # office is not defined yet
    def current(date = Date.current)
      year = years.select { |i| i <= start_year_for(date) }.max
      year && new(year)
    end

    # Defined terms that have already started, i.e., excluding upcoming ones
    def started(date = Date.current)
      years.select { |i| i <= start_year_for(date) }.map { |i| new(i) }
    end

    def people
      YAML.load_file(DIR.join('people.yml')).deep_symbolize_keys
    end
  end

  attr_reader :start_year

  def initialize(start_year)
    @start_year = start_year
  end

  def end_year
    start_year + LENGTH - 1
  end

  def to_param
    start_year.to_s
  end

  def label
    "#{start_year}–#{end_year}"
  end

  def ==(other)
    other.is_a?(CommitteeTerm) && other.start_year == start_year
  end

  def past?(date = Date.current)
    end_year < date.year
  end

  def upcoming?(date = Date.current)
    start_year > date.year
  end

  def current?(date = Date.current)
    self == self.class.current(date)
  end

  # Live count of active community members for the current term, or the
  # count frozen in the term file otherwise (if any)
  def members_count(date = Date.current)
    return User.community_members_active.count if current?(date)

    data[:members_count]
  end

  def statutes_url
    data[:statutes_url]
  end

  # Hash of body key => list of roles, each with +:role+ (the title) and
  # +:people+ (the person ids)
  def bodies
    data[:bodies] || {}
  end

  # Hash of person id => person data, for all people serving in this term in
  # the order of config/committee/people.yml
  def people
    ids = bodies.values.flatten.flat_map { |i| i[:people] }.map(&:to_sym)
    all = self.class.people
    unknown = ids - all.keys
    if unknown.any?
      raise(KeyError, "Unknown people in committee term #{start_year}: " +
                      unknown.uniq.join(', '))
    end

    all.slice(*all.keys & ids)
  end

  private

  def data
    @data ||= YAML.load_file(DIR.join("#{start_year}.yml")).deep_symbolize_keys
  end
end
