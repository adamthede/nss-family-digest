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

ActiveRecord::Schema[8.0].define(version: 2025_03_30_211028) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ahoy_clicks", force: :cascade do |t|
    t.string "campaign"
    t.string "token"
    t.index ["campaign"], name: "index_ahoy_clicks_on_campaign"
  end

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_messages", force: :cascade do |t|
    t.string "user_type"
    t.bigint "user_id"
    t.string "to"
    t.string "mailer"
    t.text "subject"
    t.datetime "sent_at"
    t.string "campaign"
    t.index ["campaign"], name: "index_ahoy_messages_on_campaign"
    t.index ["to"], name: "index_ahoy_messages_on_to"
    t.index ["user_type", "user_id"], name: "index_ahoy_messages_on_user"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "answers", id: :serial, force: :cascade do |t|
    t.text "answer"
    t.integer "question_record_id"
    t.integer "user_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["question_record_id", "user_id"], name: "index_answers_on_question_record_id_and_user_id"
  end

  create_table "group_question_tags", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "question_id", null: false
    t.bigint "tag_id", null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_group_question_tags_on_created_by_id"
    t.index ["group_id", "question_id", "tag_id"], name: "idx_group_question_tags_unique", unique: true
    t.index ["group_id", "tag_id"], name: "index_group_question_tags_on_group_id_and_tag_id"
    t.index ["group_id"], name: "index_group_question_tags_on_group_id"
    t.index ["question_id"], name: "index_group_question_tags_on_question_id"
    t.index ["tag_id"], name: "index_group_question_tags_on_tag_id"
  end

  create_table "group_question_votes", force: :cascade do |t|
    t.bigint "group_question_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_question_id", "user_id"], name: "index_group_question_votes_on_group_question_id_and_user_id", unique: true
    t.index ["group_question_id"], name: "index_group_question_votes_on_group_question_id"
    t.index ["user_id"], name: "index_group_question_votes_on_user_id"
  end

  create_table "group_questions", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "question_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "question_id"], name: "index_group_questions_on_group_id_and_question_id", unique: true
    t.index ["group_id"], name: "index_group_questions_on_group_id"
    t.index ["question_id"], name: "index_group_questions_on_question_id"
  end

  create_table "groups", id: :serial, force: :cascade do |t|
    t.string "name", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
    t.datetime "last_activity_at", precision: nil
    t.string "plan", default: "free"
    t.integer "storage_used", default: 0
    t.string "question_mode", default: "automatic"
    t.date "paused_until"
  end

  create_table "memberships", id: :serial, force: :cascade do |t|
    t.integer "user_id"
    t.integer "group_id"
    t.boolean "active", default: false, null: false
    t.datetime "invitation_accepted_at"
    t.string "invitation_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_active_at", precision: nil
    t.index ["active"], name: "index_memberships_on_active"
    t.index ["invitation_token"], name: "index_memberships_on_invitation_token", unique: true
    t.index ["user_id", "group_id"], name: "index_memberships_on_user_id_and_group_id", unique: true
  end

  create_table "question_cycles", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "question_id", null: false
    t.bigint "question_record_id"
    t.date "start_date"
    t.date "end_date"
    t.date "digest_date"
    t.integer "status", default: 0
    t.boolean "manual", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_question_cycles_on_group_id"
    t.index ["question_id"], name: "index_question_cycles_on_question_id"
    t.index ["question_record_id"], name: "index_question_cycles_on_question_record_id"
  end

  create_table "question_records", id: :serial, force: :cascade do |t|
    t.integer "question_id"
    t.integer "group_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["group_id", "question_id"], name: "index_question_records_on_group_id_and_question_id"
  end

  create_table "question_tags", force: :cascade do |t|
    t.bigint "question_id", null: false
    t.bigint "tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["question_id", "tag_id"], name: "index_question_tags_on_question_id_and_tag_id", unique: true
    t.index ["question_id"], name: "index_question_tags_on_question_id"
    t.index ["tag_id"], name: "index_question_tags_on_tag_id"
  end

  create_table "questions", id: :serial, force: :cascade do |t|
    t.string "question", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "user_id"
    t.boolean "global", default: false, null: false
    t.string "category"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "users", id: :serial, force: :cascade do |t|
    t.string "email", limit: 255, default: "", null: false
    t.string "encrypted_password", limit: 255, default: "", null: false
    t.string "reset_password_token", limit: 255
    t.datetime "reset_password_sent_at", precision: nil
    t.datetime "remember_created_at", precision: nil
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at", precision: nil
    t.datetime "last_sign_in_at", precision: nil
    t.string "current_sign_in_ip", limit: 255
    t.string "last_sign_in_ip", limit: 255
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "profile_image", limit: 255
    t.boolean "global_admin", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["global_admin"], name: "index_users_on_global_admin", unique: true, where: "(global_admin = true)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "group_question_tags", "groups"
  add_foreign_key "group_question_tags", "questions"
  add_foreign_key "group_question_tags", "tags"
  add_foreign_key "group_question_tags", "users", column: "created_by_id"
  add_foreign_key "group_question_votes", "group_questions"
  add_foreign_key "group_question_votes", "users"
  add_foreign_key "group_questions", "groups"
  add_foreign_key "group_questions", "questions"
  add_foreign_key "question_cycles", "groups"
  add_foreign_key "question_cycles", "question_records"
  add_foreign_key "question_cycles", "questions"
  add_foreign_key "question_tags", "questions"
  add_foreign_key "question_tags", "tags"
end
