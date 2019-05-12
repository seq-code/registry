# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20190412155301) do

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
    t.index ["doi"], name: "index_publications_on_doi", unique: true
  end

  create_table "subjects", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_subjects_on_name", unique: true
  end

end
