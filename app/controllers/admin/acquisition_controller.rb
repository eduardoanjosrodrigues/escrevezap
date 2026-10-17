module Admin
  # Funil de aquisição a partir do primeiro contato com o bot: de qual botão do
  # site (acquisition_ref) e canal (acquisition_channel) vieram os contatos, e
  # quantos transcreveram, voltaram e assinaram. Visitas e cliques ficam no
  # Umami; aqui começa no que o banco enxerga.
  class AcquisitionController < Admin::BaseController
    PERIODS = { "7" => 7.days, "30" => 30.days, "90" => 90.days }.freeze

    def show
      @period = PERIODS.key?(params[:period]) || params[:period] == "all" ? params[:period] : "30"

      @channel = params[:channel].presence

      users = User.where.not(acquisition_ref: nil)
      users = users.where(created_at: PERIODS[@period].ago..) unless @period == "all"
      users = filter_channel(users) if @channel
      users = users.pluck(:id, :acquisition_ref, :acquisition_channel, :plan, :created_at, :name, :provider, :uid)

      # transcrições concluídas e dias distintos com transcrição, por usuário
      activity = UsageEvent.where(event_type: UsageEvent::TRANSCRIPTION_COMPLETED, user_id: users.map(&:first))
                           .group(:user_id)
                           .pluck(:user_id, Arel.sql("COUNT(*)"), Arel.sql("COUNT(DISTINCT DATE(occurred_at))"))
                           .to_h { |id, count, days| [ id, { count: count, days: days } ] }

      # Custo das mensagens do bot oficial no período (WhatsappCost). Os leads
      # do período nasceram dentro dele, então todas as mensagens deles estão aqui.
      since = PERIODS[@period]&.ago
      wa_messages = WhatsappCost.messages(since: since)
      @whatsapp = WhatsappCost.summary(wa_messages)
      wa_cost_by_user = WhatsappCost.estimated_by_user(wa_messages)

      rows = users.map do |id, ref, channel, plan, created_at, name, provider, uid|
        stats = activity[id] || { count: 0, days: 0 }
        ddd = User.ddd_of(uid) if provider == "phone"
        { id: id, ref: ref, channel: channel.presence || "—", plan: plan, created_at: created_at, name: name,
          ddd: ddd || "—", state: User::DDD_STATES[ddd] || "—", whatsapp_usd: wa_cost_by_user[id],
          transcribed: stats[:count] > 0, returned: stats[:days] >= 2, paid: plan != "free" }
      end

      @total     = funnel(rows)
      @by_ref    = rows.group_by { |r| r[:ref] }.transform_values { |rs| funnel(rs) }.sort_by { |_, f| -f[:contacts] }
      @by_page   = rows.group_by { |r| page_of(r[:ref]) }.transform_values { |rs| funnel(rs) }.sort_by { |_, f| -f[:contacts] }
      @by_channel = rows.group_by { |r| r[:channel] }.transform_values { |rs| funnel(rs) }.sort_by { |_, f| -f[:contacts] }
      @by_state  = rows.group_by { |r| r[:state] }.transform_values { |rs| funnel(rs) }.sort_by { |_, f| -f[:contacts] }
      @by_ddd    = rows.group_by { |r| r[:ddd] == "—" ? "—" : "#{r[:ddd]} · #{r[:state]}" }
                       .transform_values { |rs| funnel(rs) }.sort_by { |_, f| -f[:contacts] }
      @recent    = rows.sort_by { |r| r[:created_at] }.last(25).reverse
      @untracked = User.where(acquisition_ref: nil).count
      @payment_funnel = payment_funnel
    end

    private

    # "—" na tabela "Por canal" é quem chegou sem canal (acesso direto)
    def filter_channel(users)
      @channel == "—" ? users.where(acquisition_channel: [ nil, "" ]) : users.where(acquisition_channel: @channel)
    end

    PAYMENT_STEPS = [ UsageEvent::LIMIT_REACHED, UsageEvent::CHECKOUT_STARTED,
                      UsageEvent::PIX_GENERATED, UsageEvent::SUBSCRIPTION_ACTIVATED ].freeze

    # Usuários distintos em cada passo do funil de pagamento no período
    # (todos os usuários, não só os com código de aquisição).
    def payment_funnel
      events = UsageEvent.where(event_type: PAYMENT_STEPS)
      events = events.where(occurred_at: PERIODS[@period].ago..) unless @period == "all"
      counts = events.group(:event_type).distinct.count(:user_id)
      PAYMENT_STEPS.index_with { |step| counts[step] || 0 }
    end

    def funnel(rows)
      { contacts:    rows.size,
        transcribed: rows.count { |r| r[:transcribed] },
        returned:    rows.count { |r| r[:returned] },
        paid:        rows.count { |r| r[:paid] },
        whatsapp_usd: rows.sum { |r| r[:whatsapp_usd] } }
    end

    # "home-planos-pro" → "home", "seo-advogado-topo" → "seo-advogado"
    def page_of(ref)
      case ref
      when /\Aseo-(.+)-(topo|meio|fim)\z/ then "seo-#{Regexp.last_match(1)}"
      when /\A(home|precos)-/ then Regexp.last_match(1)
      else ref
      end
    end
  end
end
