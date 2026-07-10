class CreateWikispeciesCredentials < ActiveRecord::Migration[6.1]
  def change
    create_table :wikispecies_credentials do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :encrypted_access_token, null: false
      t.text :encrypted_refresh_token
      t.string :wiki_username, null: false
      t.datetime :expires_at

      t.timestamps
    end
  end
end
