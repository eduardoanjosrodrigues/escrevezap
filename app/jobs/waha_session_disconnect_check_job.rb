# Agendado quando uma sessão sai de working. O WAHA reinicia sessões saudáveis
# o tempo todo (working → starting → working em segundos), então só avisamos
# quando a sessão realmente caiu (failed / scan_qr_code). Se ainda estiver em
# starting, confere de novo mais tarde.
class WahaSessionDisconnectCheckJob < ApplicationJob
  include Loggable

  queue_as :default

  MAX_CHECKS   = 5
  RECHECK_WAIT = 2.minutes

  def perform(waha_session_id, check = 1)
    session = WahaSession.find_by(id: waha_session_id)
    return unless session
    # working: voltou sozinha. stopped/pending: desconexão pedida pelo usuário.
    return if session.working? || session.stopped? || session.pending?

    if session.starting? && check < MAX_CHECKS
      self.class.set(wait: RECHECK_WAIT).perform_later(waha_session_id, check + 1)
      return
    end

    user = session.user
    return unless mark_notified(session)

    log_info "Sessão desconectada, avisando usuário",
      event: "whatsapp_disconnect_notice_sent",
      user_id: user.id,
      waha_session_id: session.id,
      waha_status: session.waha_status,
      provider: user.provider

    user.notify(
      subject:   I18n.t("whatsapp_notices.disconnected.subject"),
      text:      disconnect_text(user),
      template:  Meta::RenderTemplate.new(nil).whatsapp_desconectado,
      email_cta: {
        label: I18n.t("whatsapp_notices.disconnected.email_cta"),
        url:   Rails.application.routes.url_helpers.app_waha_session_url(**Rails.application.config.action_mailer.default_url_options)
      }
    )
  end

  private

  # Um aviso por desconexão: se já avisamos e a sessão não voltou a working
  # desde então, é a mesma queda (ex.: vários jobs da mesma sessão).
  def mark_notified(session)
    session.with_lock do
      last = session.disconnect_notified_at
      reconnected_since = last && session.waha_session_events.where(to_status: "working").where("occurred_at > ?", last).exists?
      return false if last && !reconnected_since

      session.update_column(:disconnect_notified_at, Time.current)
    end
    true
  end

  def disconnect_text(user)
    key = user.provider == "phone" ? "text_whatsapp" : "text_email"
    I18n.t("whatsapp_notices.disconnected.#{key}")
  end
end
