class UpdateNomenclaturalTypes < ActiveRecord::Migration[6.1]
  # It is generally considered bad practice to include data manipulation in a
  # database migration, but unfortunately I cannot ensure that data isn't lost
  # otherwise
  def up
    Name.where.not(type_material: nil).each do |name|
      name.nomenclatural_type_type = name.type_material
      name.nomenclatural_type_entry = name.type_accession
      type = name.nomenclatural_type_from_entry
      name.update_columns(
        nomenclatural_type_type: type.class.to_s,
        nomenclatural_type_id: type.id
      ) unless type.nil?
    end
  end

  def down
    Name.where.not(nomenclatural_type_type: nil).each do |name|
      type = name.nomenclatural_type
      type_material, type_accession = type.old_type_definition
      name.update_columns(
        type_material: type_material,
        type_accession: type_accession
      )
    end
  end
end
