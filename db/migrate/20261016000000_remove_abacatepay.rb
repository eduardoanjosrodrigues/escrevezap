class RemoveAbacatepay < ActiveRecord::Migration[8.1]
  def up
    remove_index  :subscriptions, :abacatepay_subscription_id, if_exists: true
    remove_column :subscriptions, :abacatepay_subscription_id
    remove_column :subscriptions, :abacatepay_customer_id
    remove_column :subscriptions, :abacatepay_checkout_url
    change_column_default :subscriptions, :provider, from: "abacatepay", to: "inter"

    drop_table :billing_events
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
