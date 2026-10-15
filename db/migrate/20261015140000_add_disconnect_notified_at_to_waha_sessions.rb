class AddDisconnectNotifiedAtToWahaSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :waha_sessions, :disconnect_notified_at, :datetime
  end
end
