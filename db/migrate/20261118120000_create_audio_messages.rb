class CreateAudioMessages < ActiveRecord::Migration[8.1]
  def change
    # Áudios que chegam pelo webhook do Waxum, com as chaves para baixar a
    # mídia. No modo reação a transcrição só é pedida depois (reagindo ao
    # áudio), e o webhook da reação traz apenas o id da mensagem.
    create_table :audio_messages do |t|
      t.references :waha_session, null: false, foreign_key: true
      t.string :message_id, null: false
      t.string :chat_jid, null: false
      t.string :phone, null: false
      t.boolean :from_me, null: false, default: false
      t.string :mimetype
      t.integer :seconds
      t.string :direct_path, null: false
      t.string :media_key, null: false
      t.string :file_sha256, null: false
      t.string :file_enc_sha256, null: false
      t.bigint :file_length, null: false
      t.timestamps
    end
    add_index :audio_messages, [ :waha_session_id, :message_id ], unique: true
    add_index :audio_messages, :created_at

    # O áudio já fica anexado à transcrição; a linha pode ser apagada depois
    # (AudioMessage::RETENTION).
    add_reference :transcriptions, :audio_message, foreign_key: { on_delete: :nullify }
  end
end
