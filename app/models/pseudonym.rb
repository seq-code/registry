class Pseudonym < ApplicationRecord
  belongs_to :name
  validates(:name, presence: true)
  validates(:pseudonym, presence: true)

  class << self
    def kind_texts
      {
        common: 'Colloquial or common name',
        placeholder: 'Alphanumeric placeholder accession',
        misspelling: 'Misspelling or other orthographic variants'
      }
    end

    def kind_opts
      kind_texts.to_a.map(&:reverse)
    end
  end

  def kind_text
    self.class.kind_texts[kind&.to_sym]
  end
end
