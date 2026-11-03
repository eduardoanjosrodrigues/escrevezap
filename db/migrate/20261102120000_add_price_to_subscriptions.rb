class AddPriceToSubscriptions < ActiveRecord::Migration[8.1]
  def up
    # Preço fechado na assinatura: o Pix Automático é autorizado com valorRec
    # fixo, então mudar Subscription::PRICES só vale para quem assinar depois.
    add_column :subscriptions, :price, :decimal, precision: 8, scale: 2

    execute <<~SQL
      UPDATE subscriptions SET price = CASE plan WHEN 'pro' THEN 19.90 ELSE 4.99 END
    SQL
  end

  def down
    remove_column :subscriptions, :price
  end
end
