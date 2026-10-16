class AddAcquisitionToUsers < ActiveRecord::Migration[8.1]
  def change
    # De onde veio o contato (primeira mensagem ao bot): botão do site
    # ("home-hero", "seo-advogado-topo", "direto" sem código) e canal
    # ("google", "instagram", utm_campaign). Nulo = usuário anterior ao rastreio.
    add_column :users, :acquisition_ref, :string
    add_column :users, :acquisition_channel, :string
    add_index  :users, :acquisition_ref
  end
end
