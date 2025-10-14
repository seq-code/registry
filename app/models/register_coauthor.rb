class RegisterCoauthor < ApplicationRecord
  belongs_to(:register)
  belongs_to(:user)
  validates(
    :order, presence: true,
    numericality: { only_integer: true, greater_than: 0 }
  )
  validates(:user, uniqueness: { scope: :register })

  after_destroy(:update_coauthors_order)

  def move_up
    return if order <= 1

    register.register_coauthor.where(order: order - 1)
      .update(order: order) && update(order: order - 1)
  end

  private

  def update_coauthors_order
    register.reload
    register.register_coauthors.each_with_index do |rc, k|
      rc.update(order: k)
    end
  end
end
