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

ActiveRecord::Schema[8.1].define(version: 2025_12_01_134806) do
  create_table "answer_comments", force: :cascade do |t|
    t.integer "answer_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["answer_id"], name: "index_answer_comments_on_answer_id"
    t.index ["user_id"], name: "index_answer_comments_on_user_id"
  end

  create_table "answer_revisions", force: :cascade do |t|
    t.integer "answer_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["answer_id"], name: "index_answer_revisions_on_answer_id"
    t.index ["user_id"], name: "index_answer_revisions_on_user_id"
  end

  create_table "answers", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.text "redacted_body"
    t.integer "redacted_by_id"
    t.string "redacted_reason"
    t.string "redaction_state", default: "visible", null: false
    t.boolean "show_real_identity", default: false, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["post_id"], name: "index_answers_on_post_id"
    t.index ["redacted_by_id"], name: "index_answers_on_redacted_by_id"
    t.index ["user_id"], name: "index_answers_on_user_id"
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.integer "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.json "metadata", default: {}, null: false
    t.integer "performed_by_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable"
    t.index ["performed_by_id"], name: "index_audit_logs_on_performed_by_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "bookmarks", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["post_id"], name: "index_bookmarks_on_post_id"
    t.index ["user_id", "post_id"], name: "index_bookmarks_on_user_id_and_post_id", unique: true
    t.index ["user_id"], name: "index_bookmarks_on_user_id"
  end

  create_table "likes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "vote_type", default: 1, null: false
    t.index ["post_id"], name: "index_likes_on_post_id"
    t.index ["user_id"], name: "index_likes_on_user_id"
  end

  create_table "post_revisions", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["post_id"], name: "index_post_revisions_on_post_id"
    t.index ["user_id"], name: "index_post_revisions_on_user_id"
  end

  create_table "post_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id", "tag_id"], name: "index_post_tags_on_post_id_and_tag_id", unique: true
    t.index ["post_id"], name: "index_post_tags_on_post_id"
    t.index ["tag_id"], name: "index_post_tags_on_tag_id"
  end

  create_table "posts", force: :cascade do |t|
    t.integer "accepted_answer_id"
    t.text "ai_categories"
    t.boolean "ai_flagged", default: false, null: false
    t.text "ai_scores"
    t.boolean "appeal_requested", default: false, null: false
    t.text "body"
    t.string "course_code"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.datetime "locked_at"
    t.text "redacted_body"
    t.integer "redacted_by_id"
    t.string "redacted_reason"
    t.string "redaction_state", default: "visible", null: false
    t.string "school"
    t.datetime "screened_at"
    t.boolean "show_real_identity", default: false, null: false
    t.string "status", default: "open", null: false
    t.string "title"
    t.integer "topic_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["accepted_answer_id"], name: "index_posts_on_accepted_answer_id"
    t.index ["ai_flagged"], name: "index_posts_on_ai_flagged"
    t.index ["course_code"], name: "index_posts_on_course_code"
    t.index ["expires_at"], name: "index_posts_on_expires_at"
    t.index ["locked_at"], name: "index_posts_on_locked_at"
    t.index ["redacted_by_id"], name: "index_posts_on_redacted_by_id"
    t.index ["school"], name: "index_posts_on_school"
    t.index ["status"], name: "index_posts_on_status"
    t.index ["topic_id"], name: "index_posts_on_topic_id"
    t.index ["user_id"], name: "index_posts_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", limit: 1024, null: false
    t.integer "channel_hash", limit: 8, null: false
    t.datetime "created_at", null: false
    t.binary "payload", limit: 536870912, null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_tags_on_slug", unique: true
  end

  create_table "thread_identities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "post_id", null: false
    t.string "pseudonym", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["post_id"], name: "index_thread_identities_on_post_id"
    t.index ["user_id", "post_id"], name: "index_thread_identities_on_user_id_and_post_id", unique: true
    t.index ["user_id"], name: "index_thread_identities_on_user_id"
  end

  create_table "topics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_topics_on_name", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.text "moderation_notes"
    t.string "provider"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "answer_comments", "answers"
  add_foreign_key "answer_comments", "users"
  add_foreign_key "answer_revisions", "answers"
  add_foreign_key "answer_revisions", "users"
  add_foreign_key "answers", "posts"
  add_foreign_key "answers", "users"
  add_foreign_key "answers", "users", column: "redacted_by_id"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "audit_logs", "users", column: "performed_by_id"
  add_foreign_key "bookmarks", "posts"
  add_foreign_key "bookmarks", "users"
  add_foreign_key "likes", "posts"
  add_foreign_key "likes", "users"
  add_foreign_key "post_revisions", "posts"
  add_foreign_key "post_revisions", "users"
  add_foreign_key "post_tags", "posts"
  add_foreign_key "post_tags", "tags"
  add_foreign_key "posts", "answers", column: "accepted_answer_id"
  add_foreign_key "posts", "topics"
  add_foreign_key "posts", "users"
  add_foreign_key "posts", "users", column: "redacted_by_id"
  add_foreign_key "thread_identities", "posts"
  add_foreign_key "thread_identities", "users"
end
