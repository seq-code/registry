class AddEtymologyToNames < ActiveRecord::Migration[6.0]
  def change
    add_column :names, :etymology_xx_lang, :string
    add_column :names, :etymology_xx_grammar, :string
    add_column :names, :etymology_xx_description, :string
    add_column :names, :etymology_p1_lang, :string
    add_column :names, :etymology_p1_grammar, :string
    add_column :names, :etymology_p1_particle, :string
    add_column :names, :etymology_p1_description, :string
    add_column :names, :etymology_p2_lang, :string
    add_column :names, :etymology_p2_grammar, :string
    add_column :names, :etymology_p2_particle, :string
    add_column :names, :etymology_p2_description, :string
    add_column :names, :etymology_p3_lang, :string
    add_column :names, :etymology_p3_grammar, :string
    add_column :names, :etymology_p3_particle, :string
    add_column :names, :etymology_p3_description, :string
    add_column :names, :etymology_p4_lang, :string
    add_column :names, :etymology_p4_grammar, :string
    add_column :names, :etymology_p4_particle, :string
    add_column :names, :etymology_p4_description, :string
    add_column :names, :etymology_p5_lang, :string
    add_column :names, :etymology_p5_grammar, :string
    add_column :names, :etymology_p5_particle, :string
    add_column :names, :etymology_p5_description, :string
  end
end
