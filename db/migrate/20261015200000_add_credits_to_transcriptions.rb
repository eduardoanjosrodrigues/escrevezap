class AddCreditsToTranscriptions < ActiveRecord::Migration[8.1]
  def change
    # Quantas transcrições da cota mensal este áudio consome. Áudios longos
    # confirmados pelo usuário custam ceil(duração / 25 min).
    add_column :transcriptions, :credits, :integer, null: false, default: 1
  end
end
