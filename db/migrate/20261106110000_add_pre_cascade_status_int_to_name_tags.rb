class AddPreCascadeStatusIntToNameTags < ActiveRecord::Migration[6.1]
  def change
    # Status a name tag had before it was auto-accepted through an implying
    # tag (-1 if it was created by the cascade), or nil if it wasn't
    add_column :name_tags, :pre_cascade_status_int, :integer
  end
end
