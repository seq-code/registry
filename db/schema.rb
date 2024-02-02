# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2024_02_02_093304) do

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.integer "record_id", null: false
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.integer "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "authors", force: :cascade do |t|
    t.string "given"
    t.string "family"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["given", "family"], name: "index_authors_on_given_and_family", unique: true
  end

  create_table "checks", force: :cascade do |t|
    t.integer "name_id", null: false
    t.integer "user_id", null: false
    t.text "kind", null: false
    t.boolean "pass"
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name_id", "kind"], name: "index_checks_on_name_id_and_kind", unique: true
    t.index ["name_id"], name: "index_checks_on_name_id"
    t.index ["user_id"], name: "index_checks_on_user_id"
  end

  create_table "genomes", force: :cascade do |t|
    t.string "database", null: false
    t.string "accession", null: false
    t.float "gc_content"
    t.float "completeness"
    t.float "contamination"
    t.float "seq_depth"
    t.float "most_complete_16s"
    t.integer "number_of_16s"
    t.float "most_complete_23s"
    t.integer "number_of_23s"
    t.integer "number_of_trnas"
    t.integer "updated_by_id"
    t.boolean "auto_check", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "kind"
    t.string "source_database"
    t.string "source_accession"
    t.float "gc_content_auto"
    t.float "completeness_auto"
    t.float "contamination_auto"
    t.float "most_complete_16s_auto"
    t.integer "number_of_16s_auto"
    t.float "most_complete_23s_auto"
    t.integer "number_of_23s_auto"
    t.integer "number_of_trnas_auto"
    t.datetime "auto_scheduled_at"
    t.text "auto_failed"
    t.float "coding_density_auto"
    t.integer "n50_auto"
    t.integer "contigs_auto"
    t.integer "assembly_length_auto"
    t.float "ambiguous_fraction_auto"
    t.string "codon_table_auto"
    t.datetime "queued_external"
    t.text "source_json"
    t.integer "largest_contig_auto"
    t.index ["database", "accession"], name: "index_genomes_uniqueness", unique: true
    t.index ["updated_by_id"], name: "index_genomes_on_updated_by_id"
  end

  create_table "name_correspondences", force: :cascade do |t|
    t.integer "name_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "automatic", default: false
    t.index ["name_id"], name: "index_name_correspondences_on_name_id"
    t.index ["user_id"], name: "index_name_correspondences_on_user_id"
  end

  create_table "names", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "proposed_in_id"
    t.string "syllabication"
    t.boolean "syllabication_reviewed"
    t.string "etymology_xx_lang"
    t.string "etymology_xx_grammar"
    t.string "etymology_xx_description"
    t.string "etymology_p1_lang"
    t.string "etymology_p1_grammar"
    t.string "etymology_p1_particle"
    t.string "etymology_p1_description"
    t.string "etymology_p2_lang"
    t.string "etymology_p2_grammar"
    t.string "etymology_p2_particle"
    t.string "etymology_p2_description"
    t.string "etymology_p3_lang"
    t.string "etymology_p3_grammar"
    t.string "etymology_p3_particle"
    t.string "etymology_p3_description"
    t.string "etymology_p4_lang"
    t.string "etymology_p4_grammar"
    t.string "etymology_p4_particle"
    t.string "etymology_p4_description"
    t.string "etymology_p5_lang"
    t.string "etymology_p5_grammar"
    t.string "etymology_p5_particle"
    t.string "etymology_p5_description"
    t.integer "parent_id"
    t.integer "corrigendum_in_id"
    t.string "corrigendum_from"
    t.string "rank"
    t.integer "ncbi_taxonomy"
    t.integer "status", default: 0
    t.integer "created_by_id"
    t.integer "validated_by_id"
    t.datetime "validated_at"
    t.string "type_material"
    t.text "type_accession"
    t.integer "submitted_by_id"
    t.datetime "submitted_at"
    t.text "itis_json"
    t.datetime "itis_at"
    t.integer "endorsed_by_id"
    t.datetime "endorsed_at"
    t.integer "register_id"
    t.text "irmng_json"
    t.datetime "irmng_at"
    t.text "col_json"
    t.datetime "col_at"
    t.string "incertae_sedis"
    t.integer "tutorial_id"
    t.integer "genome_id"
    t.text "gbif_json"
    t.datetime "gbif_at"
    t.datetime "queued_external"
    t.integer "nomenclature_review_by_id"
    t.datetime "priority_date"
    t.string "proposal_kind"
    t.string "nomenclatural_status"
    t.string "taxonomic_status"
    t.string "authority"
    t.string "lpsn_url"
    t.integer "correct_name_id"
    t.integer "assigned_in_id"
    t.string "genome_strain"
    t.integer "genomics_review_by_id"
    t.text "corrigendum_kind"
    t.index ["genome_id"], name: "index_names_on_genome_id"
    t.index ["name"], name: "index_names_on_name", unique: true
    t.index ["register_id"], name: "index_names_on_register_id"
    t.index ["tutorial_id"], name: "index_names_on_tutorial_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.boolean "seen", default: false
    t.boolean "notified_email", default: false
    t.integer "user_id", null: false
    t.string "notifiable_type", null: false
    t.integer "notifiable_id", null: false
    t.string "linkeable_type"
    t.integer "linkeable_id"
    t.string "action"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "title"
    t.index ["linkeable_type", "linkeable_id"], name: "index_notifications_on_linkeable"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "observe_names", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "name_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["name_id"], name: "index_observe_names_on_name_id"
    t.index ["user_id", "name_id"], name: "observe_names_uniqueness", unique: true
    t.index ["user_id"], name: "index_observe_names_on_user_id"
  end

  create_table "observe_registers", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "register_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["register_id"], name: "index_observe_registers_on_register_id"
    t.index ["user_id", "register_id"], name: "observe_registers_uniqueness", unique: true
    t.index ["user_id"], name: "index_observe_registers_on_user_id"
  end

  create_table "placements", force: :cascade do |t|
    t.integer "name_id", null: false
    t.integer "parent_id"
    t.integer "publication_id"
    t.boolean "preferred", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "incertae_sedis"
    t.boolean "gtdb_taxonomy"
    t.boolean "ncbi_taxonomy"
    t.index ["name_id"], name: "index_placements_on_name_id"
    t.index ["publication_id"], name: "index_placements_on_publication_id"
  end

  create_table "publication_authors", force: :cascade do |t|
    t.integer "publication_id"
    t.integer "author_id"
    t.string "sequence"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_publication_authors_on_author_id"
    t.index ["publication_id", "author_id"], name: "index_publication_authors_on_publication_id_and_author_id", unique: true
    t.index ["publication_id"], name: "index_publication_authors_on_publication_id"
  end

  create_table "publication_names", force: :cascade do |t|
    t.integer "publication_id"
    t.integer "name_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "emends", default: false
    t.index ["name_id"], name: "index_publication_names_on_name_id"
    t.index ["publication_id", "name_id"], name: "index_publication_names_on_publication_id_and_name_id", unique: true
    t.index ["publication_id"], name: "index_publication_names_on_publication_id"
  end

  create_table "publication_subjects", force: :cascade do |t|
    t.integer "publication_id"
    t.integer "subject_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["publication_id", "subject_id"], name: "index_publication_subjects_on_publication_id_and_subject_id", unique: true
    t.index ["publication_id"], name: "index_publication_subjects_on_publication_id"
    t.index ["subject_id"], name: "index_publication_subjects_on_subject_id"
  end

  create_table "publications", force: :cascade do |t|
    t.string "title"
    t.string "journal"
    t.string "journal_loc"
    t.date "journal_date"
    t.string "doi"
    t.string "url"
    t.string "crossref_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pub_type"
    t.string "abstract"
    t.boolean "scanned", default: false
    t.index ["doi"], name: "index_publications_on_doi", unique: true
    t.index ["journal"], name: "index_publications_on_journal"
  end

  create_table "register_correspondences", force: :cascade do |t|
    t.integer "register_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "automatic", default: false
    t.index ["register_id"], name: "index_register_correspondences_on_register_id"
    t.index ["user_id"], name: "index_register_correspondences_on_user_id"
  end

  create_table "registers", force: :cascade do |t|
    t.string "accession"
    t.integer "user_id", null: false
    t.integer "validated_by_id"
    t.boolean "submitted", default: false
    t.boolean "validated", default: false
    t.integer "publication_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "title"
    t.boolean "notified", default: false
    t.datetime "notified_at"
    t.datetime "validated_at"
    t.boolean "published"
    t.datetime "published_at"
    t.string "published_doi"
    t.integer "published_by_id"
    t.boolean "submitter_is_author"
    t.boolean "authors_approval"
    t.datetime "submitted_at"
    t.boolean "nomenclature_review", default: false
    t.boolean "genomics_review", default: false
    t.text "internal_notes"
    t.binary "certificate_image"
    t.index ["accession"], name: "index_registers_on_accession", unique: true
    t.index ["publication_id"], name: "index_registers_on_publication_id"
    t.index ["submitted"], name: "index_registers_on_submitted"
    t.index ["user_id"], name: "index_registers_on_user_id"
    t.index ["validated"], name: "index_registers_on_validated"
  end

  create_table "subjects", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_subjects_on_name", unique: true
  end

  create_table "tutorials", force: :cascade do |t|
    t.string "pipeline"
    t.integer "user_id", null: false
    t.boolean "ongoing"
    t.integer "step"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.text "data"
    t.index ["user_id"], name: "index_tutorials_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "failed_attempts", default: 0, null: false
    t.string "unlock_token"
    t.datetime "locked_at"
    t.string "username", null: false
    t.string "affiliation"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "admin", default: false
    t.boolean "contributor", default: false
    t.text "contributor_statement"
    t.boolean "curator", default: false
    t.text "curator_statement"
    t.string "family"
    t.string "given"
    t.boolean "editor", default: false
    t.string "orcid"
    t.string "affiliation_ror"
    t.boolean "opt_regular_email", default: true
    t.boolean "opt_notification", default: true
    t.boolean "opt_message_email", default: true
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "checks", "names"
  add_foreign_key "checks", "users"
  add_foreign_key "name_correspondences", "names"
  add_foreign_key "name_correspondences", "users"
  add_foreign_key "names", "genomes"
  add_foreign_key "names", "registers"
  add_foreign_key "names", "tutorials"
  add_foreign_key "notifications", "users"
  add_foreign_key "observe_names", "names"
  add_foreign_key "observe_names", "users"
  add_foreign_key "observe_registers", "registers"
  add_foreign_key "observe_registers", "users"
  add_foreign_key "placements", "names"
  add_foreign_key "placements", "publications"
  add_foreign_key "register_correspondences", "registers"
  add_foreign_key "register_correspondences", "users"
  add_foreign_key "registers", "publications"
  add_foreign_key "registers", "users"
  add_foreign_key "tutorials", "users"
end
