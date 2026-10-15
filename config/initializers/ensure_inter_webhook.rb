# Should only happen upon server startup
Rails.application.config.after_initialize do
  next unless Rails.env.production?
  # Se for com secret_key_base dummy tbm não roda
  next if ENV["SECRET_KEY_BASE_DUMMY"] == "1"

  begin
    inter_service = Inter::Service.new
    response = inter_service.check_webhook
    if response["webhookUrl"] != Inter::Service::WEBHOOK_URL
      puts "URL do webhook diferente. Atualizando para #{Inter::Service::WEBHOOK_URL}..."
      inter_service.register_webhook
      puts "Webhook do Inter atualizado com sucesso."
    else
      puts "Webhook do Inter já está registrado."
    end
  rescue Inter::Service::InterError => e
    begin
      puts "Webhook do Inter não encontrado. Tentando registrar..."
      inter_service.register_webhook
      puts "Webhook do Inter registrado com sucesso."
    rescue => e
      # Falha no Inter não pode derrubar o boot da aplicação
      Sentry.capture_exception(e)
      puts "Erro ao configurar webhook do Inter: #{e.message}"
      puts "A aplicação continuará sem o webhook configurado."
    end
  rescue => e
    Sentry.capture_exception(e)
    puts "Erro ao verificar webhook do Inter: #{e.message}"
  end
end
