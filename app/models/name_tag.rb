class NameTag < ApplicationRecord
  belongs_to(:name)
  belongs_to(:tag)

  validates(:name_id, uniqueness: { scope: :tag_id })
  validates(:status_int, presence: true, inclusion: { in: 0..2 })

  class << self
    def status
      %i[proposed accepted rejected]
    end

    def color
      %i[secondary success danger]
    end

    def status_opt
      status.each_with_index.to_a
    end
  end

  def status
    self.class.status[status_int]
  end

  def color
    self.class.color[status_int]
  end

  def accepted?
    status_int == 1
  end

  def proposed?
    status_int == 0
  end

  def rejected?
    status_int == 2
  end
end
