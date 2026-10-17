# Quem gastou os áudios grátis e não assinou recebe, 5+ dias depois da última
# transcrição, um único convite para o Basic com o quanto já economizou.
# Uma vez na vida por usuário. Roda todo dia de manhã (config/recurring.yml).
class FreeQuotaWinbackJob < BotNudgeJob
  KIND        = "winback".freeze
  IDLE_FOR    = 5.days
  MAX_PER_RUN = 50 # teto de custo: template de marketing é US$ 0,0625 cada

  def perform
    return if quiet_hours?

    candidates.first(MAX_PER_RUN).each do |user|
      notify(user)
    rescue => e
      Rails.logger.error(event: "winback_failed", user_id: user.id, error: e.message)
      Sentry.capture_exception(e)
    end
  end

  private

  # Grátis, com os áudios da vida toda gastos e sem transcrever há IDLE_FOR
  def candidates
    limit = User::TRANSCRIPTION_LIMITS["free"]
    idle_ids = UsageEvent.where(event_type: UsageEvent::TRANSCRIPTION_COMPLETED)
                         .group(:user_id)
                         .having("COUNT(*) >= ? AND MAX(occurred_at) <= ?", limit, IDLE_FOR.ago)
                         .pluck(:user_id)

    User.free.where(id: idle_ids).order(:id).reject { |user| user.follow_up_sent?(KIND) || user.active_subscriber? }
  end

  def notify(user)
    return unless reachable?(user) && user.transcription_credits_remaining.zero?
    # não empilha com o aviso de áudios recusados (os dois são templates pagos)
    return if user.follow_up_sent?(MissedAudiosNoticeJob::KIND, since: 3.days.ago)

    count   = user.transcription_limit
    minutes = minutes_saved(user)
    via = deliver(user,
                  text: "Você já transcreveu *#{count} áudios* com o EscreveZap, cerca de *#{minutes} minutos* que não precisou ouvir. 🙌\n\n" \
                        "Quer continuar? O *Basic* tem #{User::TRANSCRIPTION_LIMITS["basic"]} transcrições por mês por " \
                        "#{Reply::PlanMessages.brl(Subscription::PRICES["basic"])}.",
                  buttons: [ [ "upgrade_basic:#{KIND}", "Assinar Basic" ], [ "upgrade_dismiss", "Agora não" ] ],
                  template: Meta::RenderTemplate.new(nil).continuar_transcrevendo(count, minutes))
    record(user, KIND, via, minutes: minutes) if via
  end

  def minutes_saved(user)
    seconds = user.waha_session&.transcriptions&.completed&.sum(:audio_duration).to_f
    [ (seconds / 60).round, 1 ].max
  end
end
