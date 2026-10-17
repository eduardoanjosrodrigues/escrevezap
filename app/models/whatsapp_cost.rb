# Custo das mensagens do bot oficial (Meta Cloud API), a partir dos webhooks
# de status que a Meta manda para cada mensagem (guardados crus em
# ExternalEvent). A Meta cobra por mensagem *entregue*, então cada status
# "delivered" é uma mensagem; o status traz pricing.category / billable.
# Mensagens via WAHA (WhatsApp conectado) não passam pela Meta e custam zero.
#
# Duas visões:
#   billed    — só o que a Meta marcou billable: true (o que ela diz cobrar)
#   estimated — billed + mensagens de serviço/utility a partir de 01/10/2026,
#               quando a Meta passou a cobrar respostas dentro da janela de
#               24h, mesmo que o webhook ainda venha billable: false
#               (algumas fontes citam 1.000 grátis/mês por número; a doc da
#               Meta não confirma, então a estimativa não desconta).
#
# Tabela Brasil (+55) em USD por mensagem entregue. Conferir a cada trimestre:
# developers.facebook.com/documentation/business-messaging/whatsapp/pricing
module WhatsappCost
  RATES_USD = {
    "marketing"          => 0.0625,
    "utility"            => 0.0068,
    "authentication"     => 0.0068,
    "service"            => 0.0068, # desde 01/10/2026, mesmo valor de utility
    "general_purpose_ai" => 0.0625  # política "AI Providers" (BR desde 11/03/2026)
  }.freeze

  SERVICE_CHARGING_STARTS = Time.zone.parse("2026-10-01").freeze
  CHARGED_SINCE_POLICY    = %w[service utility].freeze

  # Uma linha por mensagem entregue no período:
  # { user_id:, category:, type:, billable:, delivered_at:, billed_usd:, estimated_usd: }
  def self.messages(since: nil)
    scope = ExternalEvent.meta
    scope = scope.where(created_at: since..) if since

    rows = scope
      .joins(Arel.sql("CROSS JOIN LATERAL jsonb_array_elements(external_events.data->'entry'->0->'changes'->0->'value'->'statuses') AS s"))
      .joins(Arel.sql("LEFT JOIN whatsapp_messages wm ON wm.message_id = s->>'id'"))
      .where(Arel.sql("s->>'status' = 'delivered'"))
      .pluck(Arel.sql("wm.user_id"), Arel.sql("s->'pricing'->>'category'"), Arel.sql("s->'pricing'->>'type'"),
             Arel.sql("s->'pricing'->>'billable'"), Arel.sql("external_events.created_at"))

    rows.map do |user_id, category, type, billable, delivered_at|
      rate     = RATES_USD.fetch(category.to_s, 0.0)
      billed   = billable == "true" ? rate : 0.0
      by_policy = delivered_at >= SERVICE_CHARGING_STARTS && CHARGED_SINCE_POLICY.include?(category) &&
                  type != "free_entry_point" ? rate : 0.0

      { user_id: user_id, category: category || "—", type: type, billable: billable == "true",
        delivered_at: delivered_at, billed_usd: billed, estimated_usd: [ billed, by_policy ].max }
    end
  end

  # Totais de uma lista de mensagens (ver .messages)
  def self.summary(messages)
    { delivered:     messages.size,
      billed_usd:    messages.sum { |m| m[:billed_usd] },
      estimated_usd: messages.sum { |m| m[:estimated_usd] },
      by_category:   messages.group_by { |m| m[:category] }.transform_values(&:size).sort_by { |_, n| -n } }
  end

  # Custo estimado por usuário (user_id => USD)
  def self.estimated_by_user(messages)
    messages.each_with_object(Hash.new(0.0)) do |m, costs|
      costs[m[:user_id]] += m[:estimated_usd] if m[:user_id]
    end
  end
end
