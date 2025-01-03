class Tutorial < ApplicationRecord
  belongs_to(:user)
  has_many(:names, dependent: :nullify)

  %i[
    species_name genus_name family_name order_name class_name phylum_name
    lowest_classified_taxon lineage_ids ranks name_description file
  ].each do |i|
    attr(i)
    attr_writer(i)
  end

  @@tutorials_hash = {}

  attr_accessor :invalid_record

  [Lineage, Batch, Subspecies, Parent, Neotype].each do |i|
    include i
    @@tutorials_hash[i.to_s.gsub(/.*::/, '').downcase.to_sym] = i.hash
  end

  def self.tutorials_hash
    return @@tutorials_hash
  end

  def symbol
    pipeline.to_sym
  end

  def tutorial_hash
    @@tutorials_hash[symbol]
  end

  %i[title prompt description steps].each do |i|
    define_method(i) { tutorial_hash[i] }
  end

  def step_name
    steps[step]
  end

  def next_step_symbol
    :"#{symbol}_step_#{'%02i' % step}"
  end

  def next_step(params, user)
    send(next_step_symbol, params, user)
  end

  def lowest_classified_taxon_obj
    @lowest_classified_taxon_obj ||=
      Name.where(id: value(:lowest_classified_taxon_id)).first
  end

  def lowest_new_name
    Name.ranks.reverse.each do |i|
      n = names.find { |j| j.rank == i }
      return n if n
    end
  end

  def current_name
    @current_name ||= Name.where(id: value(:current_name_id)).first
  end
  
  def next_action
    @next_action ||= self
  end

  def notice
    @notice ||= nil
  end

  def data_hash
    @data_hash ||= JSON.parse(data || '{}')
  end

  def value(key)
    data_hash[key.to_s]
  end

  def find_or_register_name(name, field, user)
    base = name.gsub(/^Candidatus /, '')
    n = Name.find_by_variants(base)
    if n
      unless n.can_edit?(user) || n.can_claim?(user)
        errors.add(
          field,
          'already exists, but you do not have editing or claiming privileges'
        )
        return
      end

      # Claim and correct
      n.status = 5 if n.status == 0
      n.created_by = user
      n.claimed_at = Time.now
      n.name.gsub!(/^Candidatus /, '')
    end
    n ||= Name.new(name: name, status: 5, created_by: user)

    unless n.save
      errors.add(
        field,
        'produced an internal error: ' +
          n.errors.map { |i| "#{i.attribute} #{i.message}" }.join(', ')
      )
      return nil
    end

    n
  end

  def add_to_register(register, user)
    Tutorial.transaction do
      names.each do |name|
        name.add_to_register(register, user)
      end
    end
  end

  private

    def require_params(params, keys)
      o = true
      keys.each do |i|
        if params[i].blank?
          errors.add(i, message: 'cannot be blank')
          o = false
        else
          send("#{i}=", params[i])
        end
      end
      o
    end
end

