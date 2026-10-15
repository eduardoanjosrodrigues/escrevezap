module Inter
  # Ciclos mensais do Pix Automático. O Inter não cobra sozinho: depois da
  # primeira parcela (Jornada 3), cada ciclo precisa de uma cobrança
  # recorrente (cobr) criada entre D-10 e D-2 do vencimento. Roda diariamente
  # via InterRecurringBillingJob e também é chamado pelo webhook de Pix.
  class RecurringBilling
    include Loggable

    # Janela em que criamos a cobr (regra do BCB: entre D-10 e D-2).
    CREATE_WINDOW = (2..7)

    PAID_STATUS   = "CONCLUIDA".freeze
    FAILED_STATUSES = %w[EXPIRADA REJEITADA CANCELADA].freeze
    REC_ENDED_STATUSES = %w[CANCELADA EXPIRADA REJEITADA].freeze

    def self.run_daily(today: Date.current)
      Subscription.inter_recurring.where(status: %i[active past_due]).find_each do |subscription|
        new(subscription, today: today).process
      rescue => e
        Sentry.capture_exception(e, extra: { subscription_id: subscription.id })
        Rails.logger.error "[Inter::RecurringBilling] subscription #{subscription.id}: #{e.class} #{e.message}"
      end
    end

    def initialize(subscription, today: Date.current)
      @subscription = subscription
      @today        = today
    end

    def process
      return if @subscription.next_charge_date.blank?
      return if recurrence_ended?

      sync_cobr_status if @subscription.cobr_created_for_next_charge?
      return unless @subscription.active? || @subscription.past_due?

      create_cobr_if_due
      handle_overdue
    end

    # Pagamento do ciclo confirmado (pelo polling ou pelo webhook de Pix).
    # Idempotente: só avança o ciclo uma vez por cobr.
    def mark_cycle_paid!
      return if @subscription.inter_cobr_status == PAID_STATUS

      paid_due_date = @subscription.inter_cobr_due_date || @subscription.next_charge_date
      next_due      = @subscription.next_due_date_after(paid_due_date)

      @subscription.update!(
        status:               :active,
        inter_cobr_status:    PAID_STATUS,
        current_period_start: paid_due_date,
        current_period_end:   next_due,
        next_charge_date:     next_due
      )
      @subscription.user.update!(plan: @subscription.plan)
      log_info "Ciclo pago - subscription #{@subscription.id}, próximo vencimento #{next_due}"

      notify("✅ *Pagamento da sua assinatura confirmado!*\n\nSeu plano *#{plan_name}* foi renovado até #{next_due.strftime('%d/%m/%Y')}. Obrigado! 🚀")
    end

    private

    def service
      @service ||= Service.new
    end

    def recurrence_ended?
      rec_status = service.get_recurrence(@subscription.inter_recorrencia_id)["status"]
      return false unless REC_ENDED_STATUSES.include?(rec_status)

      log_info "Recorrência #{@subscription.inter_recorrencia_id} #{rec_status} - cancelando subscription #{@subscription.id}"
      @subscription.update!(status: :cancelled, cancelled_at: Time.current)
      downgrade_user!
      notify("🚫 Sua autorização do Pix Automático foi encerrada no seu banco, então a assinatura do EscreveZap foi cancelada e você voltou ao plano Grátis.\n\nPara assinar de novo, é só abrir o menu → Seu Plano.")
      true
    end

    def sync_cobr_status
      status = service.get_recurring_charge(@subscription.inter_cobr_txid)["status"]

      if status == PAID_STATUS
        mark_cycle_paid!
      elsif status != @subscription.inter_cobr_status
        @subscription.update!(inter_cobr_status: status)
      end
    end

    def create_cobr_if_due
      return if @subscription.cobr_created_for_next_charge?

      days_until_due = (@subscription.next_charge_date - @today).to_i
      return unless CREATE_WINDOW.cover?(days_until_due)

      cobr = service.create_recurring_charge(
        id_rec:      @subscription.inter_recorrencia_id,
        due_date:    @subscription.next_charge_date,
        amount:      @subscription.price,
        description: "Assinatura EscreveZap #{plan_name}"
      )

      @subscription.update!(
        inter_cobr_txid:     cobr["txid"],
        inter_cobr_due_date: @subscription.next_charge_date,
        inter_cobr_status:   cobr["status"]
      )
    end

    def handle_overdue
      due = @subscription.next_charge_date
      return if @today <= due

      if !@subscription.cobr_created_for_next_charge? && @today == due + 1
        # A janela de criação passou sem cobr - precisa de intervenção manual.
        Sentry.capture_message("Pix Automático: cobr não criada para subscription #{@subscription.id} (vencimento #{due})")
      end

      failed = FAILED_STATUSES.include?(@subscription.inter_cobr_status)

      if failed || @today > due + Subscription::GRACE_DAYS
        expire!
      elsif @subscription.active?
        @subscription.update!(status: :past_due)
      end
    end

    def expire!
      log_info "Expirando subscription #{@subscription.id} (cobr #{@subscription.inter_cobr_txid}: #{@subscription.inter_cobr_status})"
      @subscription.update!(status: :expired)
      downgrade_user!
      notify("⚠️ Não conseguimos confirmar o pagamento da sua assinatura do EscreveZap via Pix Automático, então você voltou ao plano Grátis.\n\nSe quiser continuar no plano *#{plan_name}*, é só abrir o menu → Seu Plano e assinar de novo.")
    end

    def downgrade_user!
      @subscription.user.update!(plan: :free)
    end

    def plan_name
      @subscription.plan.to_s.capitalize
    end

    def notify(text)
      user = @subscription.user
      return unless user.provider == "phone" && user.uid.present?

      Meta::Service.new(recipient: user.uid).send_message(text)
    rescue => e
      Sentry.capture_exception(e)
      log_error "Erro ao notificar user #{user.id}: #{e.message}"
    end
  end
end
