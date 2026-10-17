class AddTranscriptionEngine < ActiveRecord::Migration[8.1]
  def change
    # Motor fixado à mão para o usuário ("deepgram", "soniox"). Nulo = segue o
    # padrão / o sorteio do teste A/B (TranscriptionEngine.for).
    add_column :users, :transcription_engine, :string

    # Motor que de fato transcreveu o áudio, para comparar os dois no admin.
    # Nulo = anterior ao teste (tudo Deepgram).
    add_column :transcriptions, :engine, :string
    add_index :transcriptions, [ :engine, :created_at ]
  end
end
