module TypeMaterial
  extend ActiveSupport::Concern

  included do
    has_many(
      :typified_names, -> { where(redirect_id: nil) },
      class_name: 'Name', as: :nomenclatural_type, dependent: :nullify
    )
  end

  # True if this record is registered as the nomenclatural type of at least
  # one Name, under any nomenclatural code.
  def is_a_type?
    typified_names.any?
  end

  # True if this record is registered as a paratype of at least one Name.
  # Only Strain currently supports paratypes; overridden there.
  def is_a_paratype?
    false
  end

  # The type-status superscript for this record's own title/display: "Ts"
  # if it types at least one SeqCode-track name, "T" if it types any other
  # (already-validated-elsewhere) name, "Pt" if it's a paratype, or nil if
  # it's none of those.
  def title_superscript
    return 'Ts' if typified_names.any?(&:seqcode_track?)
    return 'T'  if is_a_type?
    return 'Pt' if is_a_paratype?
  end
end
