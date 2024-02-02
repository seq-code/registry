class AddCertificateImageToRegisters < ActiveRecord::Migration[6.1]
  def change
    add_column :registers, :certificate_image, :binary
  end
end
