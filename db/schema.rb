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

ActiveRecord::Schema.define(version: 2021_07_16_175717) do

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
    t.bigint "byte_size", null: false
    t.string "checksum", null: false
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "authors", force: :cascade do |t|
    t.string "given"
    t.string "family"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["given", "family"], name: "index_authors_on_given_and_family", unique: true
  end

  create_table "names", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "proposed_by"
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
    t.text "description"
    t.integer "parent_id"
    t.integer "corrigendum_by"
    t.string "corrigendum_from"
    t.text "notes"
    t.string "rank"
    t.integer "ncbi_taxonomy"
    t.index ["name"], name: "index_names_on_name", unique: true
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

  create_table "subjects", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_subjects_on_name", unique: true
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
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["unlock_token"], name: "index_users_on_unlock_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
end
