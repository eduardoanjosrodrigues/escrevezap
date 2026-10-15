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

ActiveRecord::Schema[8.1].define(version: 2026_10_15_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "billing_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.boolean "processed", default: false, null: false
    t.datetime "processed_at"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_billing_events_on_event_id", unique: true
  end

  create_table "external_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.text "error_message"
    t.string "event_type"
    t.jsonb "parsed_event", default: {}
    t.string "provider", default: "waha", null: false
    t.integer "retry_count", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["event_type"], name: "index_external_events_on_event_type"
    t.index ["provider"], name: "index_external_events_on_provider"
    t.index ["status"], name: "index_external_events_on_status"
  end

  create_table "monitored_contacts", force: :cascade do |t|
    t.boolean "auto_created", default: false, null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "direction", default: "both", null: false
    t.string "display_name"
    t.boolean "enabled", default: true, null: false
    t.string "phone_number", null: false
    t.datetime "updated_at", null: false
    t.string "waha_chat_id"
    t.bigint "waha_session_id", null: false
    t.index ["auto_created"], name: "index_monitored_contacts_on_auto_created"
    t.index ["deleted_at"], name: "index_monitored_contacts_on_deleted_at"
    t.index ["waha_chat_id"], name: "index_monitored_contacts_on_waha_chat_id"
    t.index ["waha_session_id", "phone_number"], name: "index_monitored_contacts_on_waha_session_id_and_phone_number", unique: true
    t.index ["waha_session_id"], name: "index_monitored_contacts_on_waha_session_id"
  end

  create_table "provider_usages", force: :cascade do |t|
    t.float "cost_usd", default: 0.0, null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.string "provider", null: false
    t.bigint "transcription_id", null: false
    t.string "unit_type"
    t.float "units"
    t.datetime "updated_at", null: false
    t.index ["transcription_id"], name: "index_provider_usages_on_transcription_id"
  end

  create_table "sign_in_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.bigint "user_id", null: false
    t.index ["token"], name: "index_sign_in_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_sign_in_tokens_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "abacatepay_checkout_url"
    t.string "abacatepay_customer_id"
    t.string "abacatepay_subscription_id"
    t.date "billing_anchor_date"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.date "inter_cobr_due_date"
    t.string "inter_cobr_status"
    t.string "inter_cobr_txid"
    t.string "inter_recorrencia_id"
    t.string "inter_txid"
    t.date "next_charge_date"
    t.string "payer_cpf"
    t.string "payer_name"
    t.string "pending_plan"
    t.string "plan", default: "basic", null: false
    t.string "provider", default: "abacatepay", null: false
    t.string "status", default: "inactive", null: false
    t.datetime "trial_ends_at"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["abacatepay_subscription_id"], name: "index_subscriptions_on_abacatepay_subscription_id", unique: true, where: "(abacatepay_subscription_id IS NOT NULL)"
    t.index ["inter_cobr_txid"], name: "index_subscriptions_on_inter_cobr_txid", unique: true, where: "(inter_cobr_txid IS NOT NULL)"
    t.index ["inter_recorrencia_id"], name: "index_subscriptions_on_inter_recorrencia_id", unique: true, where: "(inter_recorrencia_id IS NOT NULL)"
    t.index ["inter_txid"], name: "index_subscriptions_on_inter_txid", unique: true, where: "(inter_txid IS NOT NULL)"
    t.index ["next_charge_date"], name: "index_subscriptions_on_next_charge_date"
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "transcription_errors", force: :cascade do |t|
    t.text "backtrace"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "error_class", null: false
    t.text "message", null: false
    t.string "stage", null: false
    t.bigint "transcription_id", null: false
    t.index ["stage"], name: "index_transcription_errors_on_stage"
    t.index ["transcription_id", "created_at"], name: "index_transcription_errors_on_transcription_id_and_created_at"
    t.index ["transcription_id"], name: "index_transcription_errors_on_transcription_id"
  end

  create_table "transcriptions", force: :cascade do |t|
    t.float "audio_duration"
    t.datetime "created_at", null: false
    t.string "direction", default: "incoming", null: false
    t.text "error_message"
    t.text "full_formatted"
    t.text "media_url"
    t.bigint "monitored_contact_id", null: false
    t.string "reply_message_id"
    t.string "status", default: "processing", null: false
    t.text "summary"
    t.text "transcript"
    t.datetime "updated_at", null: false
    t.string "waha_message_id"
    t.index ["monitored_contact_id", "created_at"], name: "index_transcriptions_on_monitored_contact_id_and_created_at"
    t.index ["monitored_contact_id"], name: "index_transcriptions_on_monitored_contact_id"
    t.index ["status"], name: "index_transcriptions_on_status"
    t.index ["waha_message_id"], name: "index_transcriptions_on_waha_message_id"
  end

  create_table "usage_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["event_type"], name: "index_usage_events_on_event_type"
    t.index ["user_id", "occurred_at"], name: "index_usage_events_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_usage_events_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "avatar_url"
    t.boolean "contacts_intro_dismissed", default: false, null: false
    t.jsonb "conversation_state", default: {}
    t.datetime "created_at", null: false
    t.datetime "current_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "email", null: false
    t.string "formatting_style", default: "whatsapp", null: false
    t.datetime "last_sign_in_at"
    t.string "last_sign_in_ip"
    t.string "name"
    t.boolean "onboarding_completed", default: false, null: false
    t.string "plan", default: "free", null: false
    t.string "provider"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["plan"], name: "index_users_on_plan"
    t.index ["provider", "uid"], name: "index_users_on_provider_uid", unique: true, where: "(provider IS NOT NULL)"
  end

  create_table "waha_session_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "from_status"
    t.datetime "occurred_at", null: false
    t.string "to_status", null: false
    t.datetime "updated_at", null: false
    t.bigint "waha_session_id", null: false
    t.index ["waha_session_id"], name: "index_waha_session_events_on_waha_session_id"
  end

  create_table "waha_sessions", force: :cascade do |t|
    t.string "auto_transcribe", default: "never", null: false
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "session_name", null: false
    t.string "transcription_mode", default: "reaction", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "waha_chat_id"
    t.string "waha_status", default: "pending", null: false
    t.index ["auto_transcribe"], name: "index_waha_sessions_on_auto_transcribe"
    t.index ["session_name"], name: "index_waha_sessions_on_session_name", unique: true
    t.index ["transcription_mode"], name: "index_waha_sessions_on_transcription_mode"
    t.index ["user_id"], name: "index_waha_sessions_on_user_id", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "monitored_contacts", "waha_sessions"
  add_foreign_key "provider_usages", "transcriptions"
  add_foreign_key "sign_in_tokens", "users"
  add_foreign_key "subscriptions", "users"
  add_foreign_key "transcription_errors", "transcriptions"
  add_foreign_key "transcriptions", "monitored_contacts"
  add_foreign_key "usage_events", "users"
  add_foreign_key "waha_session_events", "waha_sessions"
  add_foreign_key "waha_sessions", "users"
end
