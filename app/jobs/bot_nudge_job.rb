# Base dos avisos de reengajamento pelo bot oficial, fora do fluxo de uma
# transcrição (o TranscriptionFollowUpJob cobre o "logo depois"):
#
#   ActivationNudgeJob       — 20h depois do primeiro contato, nunca transcreveu
#   PixReminderJob           — 2h depois do Pix gerado, ainda não pagou
#   MissedAudiosNoticeJob    — áudios do WhatsApp conectado recusados por limite
#   FreeQuotaWinbackJob      — gastou os grátis e sumiu há 5+ dias
#
# Dentro da janela de 24h vai texto livre (US$ 0,0068); fora dela só template
# aprovado (marketing, US$ 0,0625) — quem não tem template não manda nada.
# Cada envio vira UsageEvent FOLLOW_UP_SENT com metadata.kind, a mesma métrica
# dos follow-ups da transcrição.
class BotNudgeJob < ApplicationJob
  queue_as :default

  QUIET_HOURS_START = 21 # nada entre 21h e 9h (horário de Brasília)
  QUIET_HOURS_END   = 9

  def self.quiet_hours?(time = Time.current)
    time.hour >= QUIET_HOURS_START || time.hour < QUIET_HOURS_END
  end

  private

  def quiet_hours? = self.class.quiet_hours?

  def next_morning
    now = Time.current
    (now.hour < QUIET_HOURS_END ? now : now + 1.day).change(hour: QUIET_HOURS_END, min: 15)
  end

  def reachable?(user)
    user.provider == "phone" && user.uid.present?
  end

  # text/buttons para a janela aberta; template ({ meta_json:, rendered_message: },
  # ver Meta::RenderTemplate) para a fechada. Devolve :text, :template ou nil.
  def deliver(user, text:, buttons: [], template: nil)
    meta = Meta::Service.new(recipient: user.uid)

    if user.whatsapp_window_open?
      if buttons.any?
        meta.send_message_with_buttons(text, buttons.map { |id, title| { type: "reply", reply: { id: id, title: title } } })
      else
        meta.send_message(text)
      end
      :text
    elsif template
      meta.send_template(template[:meta_json], rendered_message: template[:rendered_message])
      :template
    end
  end

  def record(user, kind, via, **metadata)
    UsageEvent.track(user: user, event_type: UsageEvent::FOLLOW_UP_SENT,
                     metadata: { kind: kind, via: via.to_s, **metadata })
    Rails.logger.info(event: "bot_nudge_sent", user_id: user.id, kind: kind, via: via)
  end
end
