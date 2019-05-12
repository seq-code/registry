class CreatePublicationSubjects < ActiveRecord::Migration[5.1]
  def change
    create_table :publication_subjects do |t|
      t.integer :publication_id
      t.integer :subject_id

      t.timestamps
    end
    add_index :publication_subjects, :publication_id
    add_index :publication_subjects, :subject_id
    add_index :publication_subjects, [:publication_id, :subject_id], unique: true
  end
end
