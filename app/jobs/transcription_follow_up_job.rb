# Depois de entregar uma transcrição no chat com o bot, manda no máximo uma
# mensagem de acompanhamento, nesta ordem de prioridade:
#
#   quota_last   — acabou o saldo (último áudio grátis / limite do mês), com botões de plano
#   quota_low    — saldo baixo: restam 2 grátis, ou 20% do mês nos planos pagos
#   welcome      — quem começou encaminhando um áudio (nunca viu as boas-vindas)
#   pin_tip      — primeira transcrição: dica de fixar a conversa
#   pro_upsell   — Basic, a partir da 3ª transcrição do mês: Transcrever no chat
#
# Cada aviso vai uma vez por período (lifetime no Grátis, mês nos pagos) —
# registrado como UsageEvent FOLLOW_UP_SENT, que também serve de métrica.
class TranscriptionFollowUpJob < ApplicationJob
  queue_as :default

  FREE_LOW_REMAINING = 2
  PAID_LOW_FRACTION  = 0.2
  PRO_UPSELL_AFTER   = 3

  def perform(transcription_id)
    transcription = Transcription.find(transcription_id)
    return unless transcription.direct? && transcription.completed?

    @user    = transcription.user
    @session = @user.waha_session
    @meta    = Meta::Service.new(recipient: transcription.monitored_contact.phone_number)

    kind = pick_follow_up
    return if kind.nil?

    send(kind)
    UsageEvent.track(user: @user, event_type: UsageEvent::FOLLOW_UP_SENT,
                     metadata: { kind: kind.to_s, period: period, transcription_id: transcription.id })
    Rails.logger.info(event: "transcription_follow_up", user_id: @user.id, kind: kind, transcription_id: transcription.id)
  end

  private

  def pick_follow_up
    remaining = @user.transcription_credits_remaining
    completed = @session.transcriptions.completed.count

    if remaining.zero?
      :quota_last unless sent?(:quota_last)
    elsif remaining <= low_threshold && !sent?(:quota_low)
      :quota_low
    elsif completed == 1
      welcomed? ? :pin_tip : :welcome
    elsif @user.basic? && !@session.working? && @session.monthly_transcriptions.completed.count >= PRO_UPSELL_AFTER && !sent?(:pro_upsell)
      :pro_upsell
    end
  end

  # ── Mensagens ────────────────────────────────────────────────────────

  def quota_last
    text, buttons = Reply::PlanMessages.quota_exhausted(@user, just_used_last: true)
    buttons.any? ? send_buttons(text, buttons) : @meta.send_message(text)
  end

  def quota_low
    @meta.send_message(Reply::PlanMessages.quota_low(@user, @user.transcription_credits_remaining))
  end

  def welcome
    lines = [ "Bem-vindo ao EscreveZap! 👋 Sempre que quiser, é só me encaminhar um áudio que eu te devolvo em texto aqui.",
              Reply::PlanMessages.free_remaining_line(@user) ]
    @meta.send_message(lines.compact.join("\n\n"))
  end

  def pin_tip
    lines = [ "Pronto ✨ Dica: fixe esta conversa no topo do WhatsApp pra me achar rápido na hora de encaminhar.",
              Reply::PlanMessages.free_remaining_line(@user) ]
    @meta.send_message(lines.compact.join("\n\n"))
  end

  def pro_upsell
    send_buttons(Reply::PlanMessages.pro_upsell, [ [ "menu_connect", "⚡ Testar agora" ] ])
  end

  # ── Helpers ──────────────────────────────────────────────────────────

  def send_buttons(text, buttons)
    @meta.send_message_with_buttons(text, buttons.map { |id, title| { type: "reply", reply: { id: id, title: title } } })
  end

  def low_threshold
    @user.lifetime_quota? ? FREE_LOW_REMAINING : (@user.transcription_limit * PAID_LOW_FRACTION).floor
  end

  # Quem chegou encaminhando um áudio nunca passou pelo start_onboarding.
  def welcomed?
    @user.onboarding_completed? || @user.conversation_state.to_h["welcomed_at"].present?
  end

  def period
    @user.lifetime_quota? ? "lifetime" : Time.current.strftime("%Y-%m")
  end

  def sent?(kind)
    UsageEvent.where(user: @user, event_type: UsageEvent::FOLLOW_UP_SENT)
              .where("metadata->>'kind' = ? AND metadata->>'period' = ?", kind.to_s, period)
              .exists?
  end
end
