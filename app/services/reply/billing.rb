module Reply
  module Billing
    private

    def show_billing
      plan = @user.plan
      limit = @user.transcription_limit
      used = @session.monthly_transcription_count

      plan_name = case plan.to_s
      when "basic" then "Basic"
      when "pro" then "Pro"
      else "Grátis"
      end

      renewal_date = if @user.subscription&.active_or_trialing? && @user.subscription.current_period_end.present?
                       @user.subscription.current_period_end
      else
                       Time.current.next_month.beginning_of_month
      end

      days_left = (renewal_date.to_date - Date.current).to_i
      days_left = 0 if days_left < 0

      days_label = days_left == 1 ? "falta 1 dia" : "faltam #{days_left} dias"

      billing_text = <<~MSG
        💳 *Seu Plano & Uso*

        *   *Plano Atual:* #{plan_name}
        *   *Uso este mês:* #{used} de #{limit} transcrições.
        *   *Renovação:* #{renewal_date.strftime("%d/%m/%Y")} (_#{days_label}_)
      MSG

      send_message(message: billing_text)
      sleep 0.5.seconds

      rows = []
      rows << { id: "upgrade_basic", title: "Assinar Basic (R$5,99)", description: "500 transcrições/mês" } if plan != "basic"
      rows << { id: "upgrade_pro", title: "Assinar Pro (R$19,90)", description: "2.000 transcrições/mês + IA" } if plan != "pro"
      rows << { id: "cancel_subscription", title: "Cancelar Assinatura", description: "Voltar ao plano gratuito" } if @user.subscription&.active_or_trialing?
      rows << { id: "cancel_connection", title: "❌ Voltar ao Menu", description: "Voltar para o menu principal" }

      send_list_message(
        body_text: "Selecione uma das opções abaixo:",
        button_text: "Ver opções",
        sections: [
          {
            title: "Assinaturas & Upgrade",
            rows: rows
          }
        ]
      )
    end

    def generate_upgrade_checkout(plan)
      if @user.subscription&.active_or_trialing?
        send_message(message: "⚠️ Você já possui uma assinatura ativa. Para trocar de plano, é necessário primeiro cancelar a sua assinatura atual. Após o cancelamento, você poderá assinar o novo plano.")
        show_billing
        return
      end

      @current_conversation_state["stage"] = "waiting_for_billing_cpf"
      @current_conversation_state["pending_upgrade_plan"] = plan
      @user.update!(conversation_state: @current_conversation_state)

      send_message(message: "Para prosseguirmos com a sua assinatura via Pix Automático, preciso de alguns dados para a emissão da cobrança.\n\nPor favor, digite seu *CPF* ou *CNPJ* (apenas números):")
    end

    def process_billing_cpf(message)
      cpf_cnpj = message.gsub(/\D/, "")
      if cpf_cnpj.length == 11 || cpf_cnpj.length == 14
        @current_conversation_state["billing_cpf"] = cpf_cnpj
        @current_conversation_state["stage"] = "waiting_for_billing_name"
        @user.update!(conversation_state: @current_conversation_state)

        send_message(message: "Obrigado! Agora, por favor, digite seu *Nome Completo* (ou Razão Social):")
      else
        send_message(message: "⚠️ CPF ou CNPJ inválido. Por favor, digite novamente (apenas números):")
      end
    end

    def process_billing_name(message)
      name = message.strip
      if name.length < 3
        send_message(message: "⚠️ Por favor, digite um nome válido:")
        return
      end

      cpf = @current_conversation_state["billing_cpf"]
      plan = @current_conversation_state["pending_upgrade_plan"]

      send_message(message: "⏳ *Gerando seu Pix Automático...* Aguarde um momento.")

      amount = case plan
      when "basic" then 5.99
      when "pro" then 19.90
      else 5.99
      end

      begin
        result = Inter::PixService.setup_automatic_pix(
          amount: amount,
          cpf: cpf,
          name: name
        )

        # Encontrar ou criar a assinatura
        subscription = @user.subscription || @user.build_subscription
        subscription.update!(
          provider: "inter",
          plan: plan,
          status: :inactive,
          inter_recorrencia_id: result[:id_recorrencia],
          inter_txid: result[:txid],
          payer_cpf: cpf,
          payer_name: name,
          billing_anchor_date: Date.current, # mesmo dia do calendario.dataInicial da rec
          next_charge_date: nil,
          inter_cobr_txid: nil,
          inter_cobr_due_date: nil,
          inter_cobr_status: nil,
          current_period_start: nil,
          current_period_end: nil
        )

        # Resetar o estágio da conversação
        @current_conversation_state.delete("stage")
        @current_conversation_state.delete("pending_upgrade_plan")
        @current_conversation_state.delete("billing_cpf")
        @user.update!(conversation_state: @current_conversation_state)

        # Enviar o código Pix
        amount_cents = (amount * 100).round
        send_pix_code(
          reference_id: result[:txid],
          pix_code: result[:pix_copia_e_cola],
          total_amount_cents: amount_cents,
          description: "Assinatura EscreveZap - #{plan.capitalize}"
        )

        sleep 1.second

        # Enviar opções de suporte/confirmação
        send_list_message(
          body_text: "Assim que o pagamento for concluído e a recorrência for autorizada no seu banco, seu plano será ativado automaticamente!\n\nVocê pode cancelar a qualquer momento por aqui ou direto pelo aplicativo do banco!\n\nSe precisar de ajuda:",
          button_text: "Opções",
          sections: [
            {
              title: "Atendimento",
              rows: [
                { id: "menu_billing", title: "🔄 Já paguei", description: "Verificar se o plano já atualizou" },
                { id: "menu_support", title: "🚨 Dificuldade para pagar", description: "Falar com nosso suporte" },
                { id: "cancel_connection", title: "❌ Voltar ao Menu", description: "Voltar para o menu principal" }
              ]
            }
          ]
        )
      rescue => e
        Sentry.capture_exception(e)
        raise e unless Rails.env.production?

        Rails.logger.error "[Reply::Billing#process_billing_name] Error generating automatic pix: #{e.class} #{e.message}"

        # Resetar o estágio da conversação em caso de erro
        @current_conversation_state.delete("stage")
        @current_conversation_state.delete("pending_upgrade_plan")
        @current_conversation_state.delete("billing_cpf")
        @user.update!(conversation_state: @current_conversation_state)

        send_message(message: "⚠️ Ocorreu um erro ao gerar a cobrança do Pix Automático com o Banco Inter. Por favor, tente novamente mais tarde ou contate o suporte.")
        sleep 0.5.seconds
        show_billing
      end
    end

    def generate_abacatepay_checkout(plan)
      send_message(message: "⏳ *Gerando seu link de pagamento seguro...* Aguarde um momento.")

      product_id = case plan
      when "basic" then Rails.application.credentials.dig(:abacatepay, :product_basic_id)
      when "pro"   then Rails.application.credentials.dig(:abacatepay, :product_pro_id)
      end

      if product_id.blank?
        send_message(message: "⚠️ Desculpe, a assinatura para o plano #{plan.capitalize} está indisponível no momento. Tente novamente mais tarde.")
        show_billing
        return
      end

      external_id = "user_#{@user.id}:#{plan}:#{Time.current.to_i}"
      return_url = "https://wa.me/558296801867"

      response = Abacatepay::Client.new.subscriptions.create(
        product_id:     product_id,
        external_id:    external_id,
        completion_url: return_url,
        return_url:     return_url
      )

      if response["success"]
        checkout_url = response.dig("data", "url")
        body_text = <<~MSG
          ⚡ *Pronto! Seu link de pagamento foi gerado:*

          Clique no botão abaixo para concluir a assinatura do plano *#{plan.capitalize}*.

          Assim que a confirmação for recebida pelo nosso sistema, seu limite será atualizado na hora e eu te aviso aqui!
        MSG

        send_cta_url_message(
          body_text: body_text,
          button_text: "Realizar Pagamento ⚡",
          url: checkout_url
        )

        sleep 1.second

        send_list_message(
          body_text: "Você pode usar as opções abaixo para acompanhar sua assinatura ou pedir ajuda:",
          button_text: "Opções",
          sections: [
            {
              title: "Acompanhamento",
              rows: [
                { id: "menu_billing", title: "🔄 Já paguei", description: "Verificar se o plano já atualizou" },
                { id: "menu_support", title: "🚨 Dificuldade para pagar", description: "Falar com nosso suporte" },
                { id: "cancel_connection", title: "❌ Voltar ao Menu", description: "Voltar para o menu principal" }
              ]
            }
          ]
        )
      else
        error_msg = response["error"].presence || "Erro no checkout"
        Rails.logger.error "[Reply::Base#generate_upgrade_checkout] AbacatePay error: #{error_msg}"
        send_message(message: "⚠️ Não foi possível iniciar o checkout via Pix. Por favor, tente novamente.")
        sleep 0.5.seconds
        show_menu
      end
    end

    def process_subscription_cancellation
      subscription = @user.subscription

      unless subscription&.active_or_trialing?
        send_message(message: "⚠️ Você não possui uma assinatura ativa para cancelar.")
        show_billing
        return
      end

      if subscription.provider == "inter"
        begin
          if subscription.inter_recorrencia_id.present?
            Inter::PixService.cancel_automatic_pix(subscription.inter_recorrencia_id)
          end
          subscription.update!(status: :cancelled, cancelled_at: Time.current)
          @user.update!(plan: :free)
          send_message(message: "🚫 Sua assinatura via Pix Automático foi cancelada com sucesso. Você foi migrado de volta para o plano Grátis.")
        rescue => e
          Sentry.capture_exception(e)
          raise e unless Rails.env.production?

          Rails.logger.error "[Reply::Billing#process_subscription_cancellation] Inter error: #{e.message}"
          subscription.update!(status: :cancelled, cancelled_at: Time.current)
          @user.update!(plan: :free)
          send_message(message: "🚫 Sua assinatura foi cancelada localmente com sucesso. Caso o débito automático continue ativo no seu banco, você pode cancelá-lo diretamente pelo aplicativo da sua instituição financeira.")
        end
      else
        response = Abacatepay::Client.new.subscriptions.cancel(
          id: subscription.abacatepay_subscription_id
        )

        if response["success"]
          subscription.update!(status: :cancelled, cancelled_at: Time.current)
          @user.update!(plan: :free)
          send_message(message: "🚫 Assinatura cancelada com sucesso. Você foi migrado de volta para o plano Grátis.")
        else
          Rails.logger.error "[Reply::Base#process_subscription_cancellation] AbacatePay error: #{response['error']}"
          send_message(message: "⚠️ Não foi possível processar o cancelamento automático. Por favor, entre em contato com nosso suporte pelo email ola@escrevezap.com.br")
        end
      end

      sleep 0.5.seconds
      show_menu
    end
  end
end
