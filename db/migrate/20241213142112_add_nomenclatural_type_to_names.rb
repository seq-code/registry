class AddNomenclaturalTypeToNames < ActiveRecord::Migration[6.1]
  def change
    add_reference :names, :nomenclatural_type, polymorphic: true, null: true
  end
end
