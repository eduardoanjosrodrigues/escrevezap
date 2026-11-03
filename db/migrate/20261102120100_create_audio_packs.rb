class CreateAudioPacks < ActiveRecord::Migration[8.1]
  def change
    # Pacote avulso pago por Pix comum (cob). credits já inclui o saldo que
    # o usuário tinha ao pagar (ver AudioPack#mark_paid!).
    create_table :audio_packs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :credits, null: false
      t.decimal :price, precision: 8, scale: 2, null: false
      t.string :inter_txid, null: false
      t.datetime :paid_at
      t.timestamps
    end
    add_index :audio_packs, :inter_txid, unique: true
    add_index :audio_packs, [ :user_id, :paid_at ]
  end
end
