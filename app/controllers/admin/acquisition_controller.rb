module Admin
  # Funil de aquisição a partir do primeiro contato com o bot: de qual botão do
  # site (acquisition_ref) e canal (acquisition_channel) vieram os contatos, e
  # quantos transcreveram, voltaram e assinaram. Visitas e cliques ficam no
  # Umami; aqui começa no que o banco enxerga.
  #
  # O modo separa quem encaminha áudio ao bot (canal direct) de quem reage a
  # áudios no WhatsApp conectado (canal waha): quem reage transcreve áudios
  # que recebe de terceiros, então volume e retorno não são comparáveis.
  class AcquisitionController < Admin::BaseController
    PERIODS = { "7" => 7.days, "30" => 30.days, "90" => 90.days }.freeze
    MODES = { "direct" => "Encaminham", "waha" => "Reagem" }.freeze

    def show
      @period = PERIODS.key?(params[:period]) || params[:period] == "all" ? params[:period] : "30"

      @channel = params[:channel].presence
      @mode = params[:mode] if MODES.key?(params[:mode])

      users = User.where.not(acquisition_ref: nil)
      users = users.where(created_at: PERIODS[@period].ago..) unless @period == "all"
      users = filter_channel(users) if @channel
      users = users.pluck(:id, :acquisition_ref, :acquisition_channel, :plan, :created_at, :name, :provider, :uid)

      activity = transcription_activity(users.map(&:first))

      # Custo das mensagens do bot oficial no período (WhatsappCost). Os leads
      # do período nasceram dentro dele, então todas as mensagens deles estão aqui.
      since = PERIODS[@period]&.ago
      wa_messages = WhatsappCost.messages(since: since)
      @whatsapp = WhatsappCost.summary(wa_messages)
      wa_cost_by_user = WhatsappCost.estimated_by_user(wa_messages)

      rows = users.map do |id, ref, channel, plan, created_at, name, provider, uid|
        by_channel = activity[id] || {}
        stats = mode_stats(by_channel)
        ddd = User.ddd_of(uid) if provider == "phone"
        { id: id, ref: ref, channel: channel.presence || "—", plan: plan, created_at: created_at, name: name,
          ddd: ddd || "—", state: User::DDD_STATES[ddd] || "—", whatsapp_usd: wa_cost_by_user[id],
          usage: usage_of(by_channel), transcribed: stats[:count] > 0, returned: stats[:days] >= 2, paid: plan != "free" }
      end
      # Com modo escolhido, o funil é só de quem transcreveu naquele modo
      # (contatos que nunca transcreveram não têm modo).
      rows = rows.select { |r| activity.dig(r[:id], @mode) } if @mode

      @total     = funnel(rows)
      @by_ref    = rows.group_by { |r| r[:ref] }.transform_values { |rs| funnel(rs) }.sort_by { |_, f| -f[:contacts] }
      @by_page   = rows.group_by { |r| page_of(r[:ref]) }.transform_values { |rs| funnel(rs) }.sort_by { |_, f| -f[:contacts] }
      @by_usage  = rows.group_by { |r| r[:usage] }.transform_values { |rs| funnel(rs) }.sort_by { |_, f| -f[:contacts] }
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

    # Transcrições concluídas por usuário e canal: quantidade e dias distintos.
    # { user_id => { "direct" => { count:, dates: }, "waha" => {...} } }
    def transcription_activity(user_ids)
      Transcription.completed.joins(monitored_contact: :waha_session)
                   .where(waha_sessions: { user_id: user_ids })
                   .group("waha_sessions.user_id", :channel)
                   .pluck("waha_sessions.user_id", :channel, Arel.sql("COUNT(*)"),
                          Arel.sql("ARRAY_AGG(DISTINCT DATE(transcriptions.created_at))"))
                   .each_with_object({}) do |(id, channel, count, dates), acc|
        (acc[id] ||= {})[channel] = { count: count, dates: dates }
      end
    end

    # Sem modo, soma os canais (um dia com encaminhado e reação conta uma vez).
    def mode_stats(by_channel)
      used = @mode ? by_channel.slice(@mode).values : by_channel.values
      { count: used.sum { |s| s[:count] }, days: used.flat_map { |s| s[:dates] }.uniq.size }
    end

    def usage_of(by_channel)
      case by_channel.keys.sort
      when [ "direct" ] then "encaminha"
      when [ "waha" ] then "reage"
      when [ "direct", "waha" ] then "encaminha e reage"
      else "não transcreveu"
      end
    end

    # Usuários distintos em cada passo do funil de pagamento no período
    # (todos os usuários, não só os com código de aquisição). Com modo, só
    # quem já transcreveu naquele modo.
    def payment_funnel
      events = UsageEvent.where(event_type: PAYMENT_STEPS)
      events = events.where(occurred_at: PERIODS[@period].ago..) unless @period == "all"
      if @mode
        mode_users = Transcription.completed.where(channel: @mode).joins(monitored_contact: :waha_session)
                                  .select("waha_sessions.user_id")
        events = events.where(user_id: mode_users)
      end
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
