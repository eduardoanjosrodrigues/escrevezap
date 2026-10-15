module Inter
  class Service
    include Loggable

    PIX_KEY = Rails.application.credentials.dig(:inter, :pix_key)
    WEBHOOK_URL = "https://escrevezap.com.br/webhook/inter"

    class InterError < StandardError; end

    # Registra webhook para PIX
    def register_webhook(webhook_url = nil)
      webhook_url ||= WEBHOOK_URL
      log_info "Iniciando processo de registro do webhook..."
      log_info "URL do webhook: #{webhook_url}"
      log_info "PIX ID: #{PIX_KEY}"

      begin
        client = Client.for_webhook_write

        body = {
          webhookUrl: webhook_url
        }

        response = client.put("/pix/v2/webhook/#{PIX_KEY}", body)

        log_info "Webhook registrado com sucesso!"
        log_info "Resposta: #{response}"

        response
      end
      # rescue => e
      #   log_error "Erro ao registrar webhook: #{e.message}"
      #   raise InterError, "Falha ao registrar webhook: #{e.message}"
      # end
    end

    # Consulta status do webhook
    def check_webhook
      log_info "Iniciando processo de verificação do webhook..."
      log_info "PIX ID: #{PIX_KEY}"

      begin
        client = Client.for_webhook_read

        response = client.get("/pix/v2/webhook/#{PIX_KEY}")

        log_info "Webhook verificado com sucesso!"
        log_info "Dados do webhook: #{response.to_json}"

        response
      rescue => e
        log_error "Erro ao verificar webhook: #{e.message}"
        raise InterError, "Falha ao verificar webhook: #{e.message}"
      end
    end

    # Gera código PIX para cobrança
    def generate_pix_charge(amount:, description: nil, payer_info: {}, loc_id: nil)
      log_info "Iniciando processo de geração de código PIX..."

      begin
        client = Client.for_cob_write

        # Gerar ID único da transação (max 32 caracteres alfanuméricos)
        txid = SecureRandom.uuid.gsub("-", "")[0..31]

        log_info "Gerando cobrança PIX..."
        log_info "Transaction ID gerado: #{txid}"
        log_info "Valor da cobrança: R$ #{amount}"

        body = build_pix_charge_body(amount, description, payer_info, loc_id)

        log_info "Dados da cobrança: #{body.to_json}"

        response = client.put("/pix/v2/cob/#{txid}", body)

        log_info "Cobrança PIX gerada com sucesso!"
        log_info "Código de cópia e cola: #{response['pixCopiaECola']}" if response["pixCopiaECola"]

        response.merge("txid" => txid)
      rescue => e
        log_error "Erro ao gerar código PIX: #{e.message}"
        raise InterError, "Falha ao gerar código PIX: #{e.message}"
      end
    end

    # Cria a location para recorrência (locrec)
    def create_locrec
      log_info "Criando location para recorrência (locrec)..."
      client = Client.for_rec_write
      response = client.post("/pix/v2/locrec", { tipoCob: "rec" })
      log_info "Location de recorrência criada: #{response['id']}"
      response
    rescue => e
      log_error "Erro ao criar locrec: #{e.message}"
      raise InterError, "Falha ao criar locrec: #{e.message}"
    end

    # Cria o contrato de recorrência (rec)
    def create_recurrence(locrec_id:, txid:, amount:, devedor_cpf:, devedor_name:)
      log_info "Criando recorrência (rec) para o locrec #{locrec_id}..."
      client = Client.for_rec_write

      body = {
        loc: locrec_id.to_i,
        ativacao: { dadosJornada: { txid: txid } },
        vinculo: {
          contrato: txid[0..19],
          devedor: {
            cpf: devedor_cpf.gsub(/\D/, ""),
            nome: devedor_name
          },
          objeto: "Assinatura EscreveZap"
        },
        chave: PIX_KEY,
        calendario: {
          dataInicial: Date.current.strftime("%Y-%m-%d"),
          dataFinal: 5.years.from_now.strftime("%Y-%m-%d"),
          periodicidade: "MENSAL"
        },
        valor: {
          valorRec: format("%.2f", amount.to_f)
        },
        politicaRetentativa: "PERMITE_3R_7D"
      }

      response = client.post("/pix/v2/rec", body)
      log_info "Recorrência criada com sucesso: #{response['idRecorrencia'] || response['id']}"
      response
    rescue => e
      log_error "Erro ao criar recorrência: #{e.message}"
      raise InterError, "Falha ao criar recorrência: #{e.message}"
    end

    # Cancela a recorrência
    def cancel_recurrence(id_recorrencia)
      log_info "Cancelando recorrência com id: #{id_recorrencia}..."
      client = Client.for_rec_write
      response = client.delete("/pix/v2/rec/#{id_recorrencia}")
      log_info "Recorrência cancelada com sucesso!"
      response
    rescue => e
      log_error "Erro ao cancelar recorrência: #{e.message}"
      raise InterError, "Falha ao cancelar recorrência: #{e.message}"
    end

    # Cria a cobrança recorrente (cobr) de um ciclo da recorrência. Precisa ser
    # criada entre D-10 e D-2 do vencimento; o PSP do pagador debita na data.
    def create_recurring_charge(id_rec:, due_date:, amount:, description: "Assinatura EscreveZap")
      log_info "Criando cobrança recorrente (cobr) para #{id_rec} com vencimento #{due_date}..."
      client = Client.for_cobr_write

      body = {
        idRec: id_rec,
        infoAdicional: description.truncate(140),
        calendario: { dataDeVencimento: due_date.strftime("%Y-%m-%d") },
        valor: { original: format("%.2f", amount.to_f) },
        ajusteDiaUtil: true
      }

      agencia = Rails.application.credentials.dig(:inter, :agencia)
      conta   = Rails.application.credentials.dig(:inter, :conta)
      if agencia.present? && conta.present?
        body[:recebedor] = { agencia: agencia.to_s, conta: conta.to_i, tipoConta: "CORRENTE" } # a doc do Inter envia conta como número
      end

      response = client.post("/pix/v2/cobr", body)
      log_info "Cobrança recorrente criada: #{response['txid']} (#{response['status']})"
      response
    rescue => e
      log_error "Erro ao criar cobrança recorrente: #{e.message}"
      raise InterError, "Falha ao criar cobrança recorrente: #{e.message}"
    end

    def get_recurring_charge(txid)
      log_info "Consultando cobrança recorrente #{txid}..."
      Client.for_cobr_read.get("/pix/v2/cobr/#{txid}")
    rescue => e
      log_error "Erro ao consultar cobrança recorrente: #{e.message}"
      raise InterError, "Falha ao consultar cobrança recorrente: #{e.message}"
    end

    # Consulta a recorrência
    def get_recurrence(id_recorrencia, txid: nil)
      log_info "Consultando recorrência com id: #{id_recorrencia}..."
      client = Client.for_rec_read
      params = {}
      params[:txid] = txid if txid.present?
      response = client.get("/pix/v2/rec/#{id_recorrencia}", params)
      log_info "Recorrência consultada com sucesso!"
      response
    rescue => e
      log_error "Erro ao consultar recorrência: #{e.message}"
      raise InterError, "Falha ao consultar recorrência: #{e.message}"
    end

    # Consulta PIX recebidos
    def get_received_pix(start_date: nil, end_date: nil, page: 1, per_page: 20)
      log_info "Consultando PIX recebidos..."

      begin
        client = Client.for_pix_read

        # Definir datas padrão se não fornecidas
        start_date ||= Date.current.beginning_of_month.strftime("%Y-%m-%dT00:00:00Z")
        end_date ||= Date.current.end_of_day.strftime("%Y-%m-%dT23:59:59Z")

        params = {
          inicio: start_date,
          fim: end_date,
          "paginacao.ItensPorPagina" => per_page,
          "paginacao.PaginaAtual" => page
        }

        log_info "Período: #{start_date} a #{end_date}"
        log_info "Página: #{page}, Itens por página: #{per_page}"

        response = client.get("/pix/v2/pix", params)

        pix_list = response["pix"] || []
        log_info "PIX encontrados: #{pix_list.length}"

        if pix_list.any?
          total_value = pix_list.sum { |pix| pix["valor"].to_f }
          log_info "Valor total: R$ #{format('%.2f', total_value)}"
        end

        response
      rescue => e
        log_error "Erro ao consultar PIX recebidos: #{e.message}"
        raise InterError, "Falha ao consultar PIX recebidos: #{e.message}"
      end
    end

    def check_pix_status(end_to_end_id)
      log_info "Consultando status do PIX com endToEndId: #{end_to_end_id}..."
      client = Client.for_pix_read
      response = client.get("/pix/v2/pix/#{end_to_end_id}")
      {
        status: "paid",
        horario: response["horario"]
      }
    rescue => e
      log_error "Pix não encontrado"
      {
        status: "pending"
      }
    end

    # Consulta extrato bancário
    def get_bank_statement(start_date: nil, end_date: nil)
      log_info "Consultando extrato bancário..."

      begin
        client = Client.for_extrato_read

        # Definir datas padrão se não fornecidas (formato YYYY-MM-DD)
        start_date ||= Date.current.beginning_of_month.strftime("%Y-%m-%d")
        end_date ||= Date.current.strftime("%Y-%m-%d")

        params = {
          dataInicio: start_date,
          dataFim: end_date
        }

        log_info "Período: #{start_date} a #{end_date}"

        response = client.get("/banking/v2/extrato", params)

        transactions = response["transacoes"] || []
        log_info "Transações encontradas: #{transactions.length}"

        if transactions.any?
          credits = transactions.select { |t| t["tipoOperacao"] == "C" }
          debits = transactions.select { |t| t["tipoOperacao"] == "D" }

          credit_total = credits.sum { |t| t["valor"].to_f }
          debit_total = debits.sum { |t| t["valor"].to_f }

          log_info "Créditos: #{credits.count} - R$ #{format('%.2f', credit_total)}"
          log_info "Débitos: #{debits.count} - R$ #{format('%.2f', debit_total)}"
          log_info "Saldo líquido: R$ #{format('%.2f', credit_total - debit_total)}"
        end

        response
      rescue => e
        log_error "Erro ao consultar extrato: #{e.message}"
        raise InterError, "Falha ao consultar extrato: #{e.message}"
      end
    end

    private

    def build_pix_charge_body(amount, description, payer_info, loc_id = nil)
      body = {
        calendario: {
          expiracao: 3600  # 1 hora de expiração
        },
        valor: {
          original: format("%.2f", amount.to_f),
          modalidadeAlteracao: 0
        },
        chave: PIX_KEY,
        solicitacaoPagador: description || "EscreveZap - Assinatura",
        infoAdicionais: [
          {
            nome: "Serviço",
            valor: "Transcrição de áudios com IA"
          },
          {
            nome: "Empresa",
            valor: "EscreveZap"
          }
        ]
      }

      body[:loc] = { id: loc_id } if loc_id.present?

      # Adicionar informações do pagador se fornecidas
      if payer_info.present?
        devedor = {}

        if payer_info[:cpf]
          devedor[:cpf] = payer_info[:cpf]
        elsif payer_info[:cnpj]
          devedor[:cnpj] = payer_info[:cnpj]
        end

        devedor[:nome] = payer_info[:nome] if payer_info[:nome]

        body[:devedor] = devedor if devedor.any?
      end

      body
    end
  end
end
