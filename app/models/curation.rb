class Curation < ApplicationRecord
  belongs_to(:name)
  belongs_to(:user)
  validates(:status_int, presence: true, inclusion: { in: 0..3 })
  validates(
    :kind_int,
    presence: true, inclusion: { in: 0..2 }, uniqueness: { scope: :name }
  )

  class << self
    def kind
      %i[nomenclature genomics register]
    end

    def status
      %i[pending stop ongoing ready]
    end

    def color
      %i[secondary danger warning success]
    end

    def kind_int(kind_sym)
      kind.index(kind_sym.to_sym)
    end

    def status_opt
      status.each_with_index.map { |k, v| [v, k] }
    end
  end

  def kind
    self.class.kind[kind_int]
  end

  def status
    self.class.status[status_int]
  end

  def color
    self.class.color[status_int]
  end
end
