class AddRecurringBillingToSubscriptions < ActiveRecord::Migration[8.1]
  def change
    # Dia de início da recorrência do Pix Automático; os ciclos mensais repetem esse dia.
    add_column :subscriptions, :billing_anchor_date, :date
    # Vencimento do próximo ciclo a ser cobrado.
    add_column :subscriptions, :next_charge_date, :date
    # Última cobrança recorrente (cobr) criada no Inter.
    add_column :subscriptions, :inter_cobr_txid, :string
    add_column :subscriptions, :inter_cobr_due_date, :date
    add_column :subscriptions, :inter_cobr_status, :string

    add_index :subscriptions, :inter_cobr_txid, unique: true, where: "inter_cobr_txid IS NOT NULL"
    add_index :subscriptions, :next_charge_date
  end
end
