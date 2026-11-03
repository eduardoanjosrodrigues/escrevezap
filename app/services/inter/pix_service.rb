module Inter
  class PixService
    include Loggable

    def self.register_webhook(webhook_url = nil)
      service = Service.new
      service.register_webhook(webhook_url)
    end

    def self.check_webhook
      service = Service.new
      service.check_webhook
    end

    def self.generate_charge(amount:, description: nil, payer_cpf: nil, payer_cnpj: nil, payer_name: nil, expiration: 3600)
      service = Service.new

      payer_info = {}
      payer_info[:cpf] = payer_cpf if payer_cpf
      payer_info[:cnpj] = payer_cnpj if payer_cnpj
      payer_info[:nome] = payer_name if payer_name

      service.generate_pix_charge(
        amount: amount,
        description: description,
        payer_info: payer_info,
        expiration: expiration
      )
    end

    def self.check_pix_status(end_to_end_id)
      service = Service.new
      service.check_pix_status(end_to_end_id)
    end

    def self.get_received_pix(start_date: nil, end_date: nil, page: 1, per_page: 20)
      service = Service.new
      service.get_received_pix(
        start_date: start_date,
        end_date: end_date,
        page: page,
        per_page: per_page
      )
    end

    def self.get_bank_statement(start_date: nil, end_date: nil)
      service = Service.new
      service.get_bank_statement(start_date: start_date, end_date: end_date)
    end

    # Métodos de conveniência para diferentes cenários
    def self.generate_simple_charge(amount)
      generate_charge(amount: amount)
    end

    def self.generate_charge_with_cpf(amount:, cpf:, name: nil, description: nil)
      # Para testes, gera todos os PIX com 1 centavo
      amount = 0.01
      generate_charge(
        amount: amount,
        description: description,
        payer_cpf: cpf,
        payer_name: name
      )
    end

    def self.generate_charge_with_cnpj(amount:, cnpj:, name: nil, description: nil)
      generate_charge(
        amount: amount,
        description: description,
        payer_cnpj: cnpj,
        payer_name: name
      )
    end

    # Método para testar a integração
    def self.test_integration
      log_info "Testando integração com Banco Inter..."

      begin
        # Teste 1: Verificar webhook
        log_info "Teste 1: Verificando webhook existente..."
        webhook_info = check_webhook
        log_info "✅ Webhook funcionando: #{webhook_info['webhookUrl']}"

        # Teste 2: Gerar cobrança de teste
        log_info "Teste 2: Gerando cobrança de teste..."
        charge = generate_simple_charge(0.01) # R$ 0,01 para teste
        log_info "✅ Cobrança gerada - TxID: #{charge['txid']}"
        log_info "✅ QR Code disponível: #{charge['qrcode'].present?}"

        {
          success: true,
          webhook: webhook_info,
          test_charge: charge
        }
      rescue => e
        log_error "❌ Erro no teste de integração: #{e.message}"
        {
          success: false,
          error: e.message
        }
      end
    end


    def self.generate_qr_code_blob(pix_code)
      require "rqrcode"
      require "mini_magick"

      qrcode = RQRCode::QRCode.new(pix_code)

      png = qrcode.as_png(
        size: 400,
        border_modules: 2
      )

      image = MiniMagick::Image.read(png.to_s)

      image.combine_options do |c|
        c.colorspace "sRGB"
        c.background "white"
        c.alpha "remove"
        c.alpha "off"
        c.type "TrueColor"
        c.depth 8
        c.bordercolor "white"
        c.border 10
      end

      image.format "jpg"   # must be outside
      image.quality "95"

      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(image.to_blob),
        filename: "pix_qr_code.jpg",
        content_type: "image/jpeg"
      )
    end

    def self.setup_automatic_pix(amount:, cpf:, name:)
      service = Service.new

      # 1. Criar location de recorrência (locrec)
      locrec = service.create_locrec
      locrec_id = locrec["id"]

      # 2. Criar a cobrança imediata cob
      cob = service.generate_pix_charge(
        amount: amount,
        description: "EscreveZap - Assinatura",
        payer_info: { cpf: cpf, nome: name }
      )

      # 3. Criar a recorrência rec vinculada ao locrec e à cob
      rec = service.create_recurrence(
        locrec_id: locrec_id,
        txid: cob["txid"],
        amount: amount,
        devedor_cpf: cpf,
        devedor_name: name
      )
      id_recorrencia = rec["idRec"]

      # 4. Consultar a recorrência com txid para gerar o QrCode de Jornada 3
      rec_consulted = service.get_recurrence(id_recorrencia, txid: cob["txid"])
      pix_copia_e_cola = rec_consulted.dig("dadosQR", "pixCopiaECola")

      {
        locrec_id: locrec_id,
        txid: cob["txid"],
        id_recorrencia: id_recorrencia,
        pix_copia_e_cola: pix_copia_e_cola
      }
    end

    def self.cancel_automatic_pix(id_recorrencia)
      service = Service.new
      service.cancel_recurrence(id_recorrencia)
    end
  end
end
