# Quem tem o WhatsApp conectado e está sem saldo continua recebendo áudios que
# o EscreveZap recusa (LIMIT_REACHED com channel "waha"). O aviso de limite
# na hora vai como texto livre e some quando a janela de 24h está fechada;
# este job junta os recusados e avisa com o número real, no máximo uma vez
# por semana. Roda de hora em hora (config/recurring.yml).
class MissedAudiosNoticeJob < BotNudgeJob
  KIND       = "missed_audios".freeze
  MIN_AUDIOS = 3
  LOOKBACK   = 7.days
  COOLDOWN   = 7.days

  def perform
    return if quiet_hours?

    user_ids = refused_audios.where(occurred_at: LOOKBACK.ago..).distinct.pluck(:user_id)
    User.where(id: user_ids).find_each do |user|
      notify(user)
    rescue => e
      Rails.logger.error(event: "missed_audios_notice_failed", user_id: user.id, error: e.message)
      Sentry.capture_exception(e)
    end
  end

  private

  def notify(user)
    return unless reachable?(user)
    return unless user.transcription_credits_remaining.zero?
    return if user.follow_up_sent?(KIND, since: COOLDOWN.ago)

    missed = refused_audios.where(user: user, occurred_at: LOOKBACK.ago..).count
    return if missed < MIN_AUDIOS

    _, buttons = Reply::PlanMessages.quota_exhausted(user)
    via = deliver(user,
                  text: text(user, missed),
                  buttons: buttons.map { |id, title| [ "#{id}:#{KIND}", title ] },
                  template: Meta::RenderTemplate.new(nil).audios_nao_transcritos(missed))
    record(user, KIND, via, missed: missed, plan: user.plan) if via
  end

  def refused_audios
    UsageEvent.where(event_type: UsageEvent::LIMIT_REACHED).where("metadata->>'channel' = 'waha'")
  end

  def text(user, missed)
    limit = user.lifetime_quota? ? "seus áudios grátis acabaram" : "as transcrições do seu plano acabaram este mês"
    "Nos últimos dias, *#{missed} áudios* que chegaram no seu WhatsApp não foram transcritos porque #{limit}.\n\n" \
      "Para voltar a receber tudo em texto:\n\n#{Reply::PlanMessages.plans_overview}"
  end
end
