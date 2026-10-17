# Quem falou com o bot e nunca transcreveu nada recebe, ~20h depois do
# primeiro contato (ainda dentro da janela de 24h, então texto livre e
# barato), o passo a passo de encaminhar um áudio. Sem template: fora da
# janela não manda.
class ActivationNudgeJob < BotNudgeJob
  KIND  = "activation_nudge".freeze
  DELAY = 20.hours

  # 20h depois de agora, puxado para 20h30 da véspera se cair de madrugada
  def self.send_at(from = Time.current)
    at = from + DELAY
    return at unless quiet_hours?(at)

    (at.hour < QUIET_HOURS_END ? at - 1.day : at).change(hour: 20, min: 30)
  end

  def self.schedule(user)
    set(wait_until: send_at).perform_later(user.id)
  end

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user && reachable?(user)
    return if UsageEvent.where(user: user, event_type: UsageEvent::TRANSCRIPTION_COMPLETED).exists?
    return if user.follow_up_sent?(KIND)

    via = deliver(user, text: text(user))
    record(user, KIND, via) if via
  end

  private

  def text(user)
    [ "Oi! Ainda não testou? É bem rápido 👇",
      "1. Abra qualquer conversa que tenha um áudio\n2. Segure o áudio e toque em *Encaminhar*\n3. Escolha *EscreveZap*",
      "Em segundos eu te devolvo o texto aqui.",
      Reply::PlanMessages.free_remaining_line(user) ].compact.join("\n\n")
  end
end
