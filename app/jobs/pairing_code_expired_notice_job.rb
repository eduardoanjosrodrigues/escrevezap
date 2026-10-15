# Avisa pelo bot quando o código de pareamento que o usuário pediu expirou
# (WAHA leva a sessão de scan_qr_code para failed ~2min40 depois do código).
#
# Só dispara para quem pediu um código nos últimos minutos: nos reinícios em
# massa do WAHA todas as sessões failed voltam a scan_qr_code e expiram de novo
# sem ninguém ter pedido nada, e esses usuários não devem receber aviso.
class PairingCodeExpiredNoticeJob < ApplicationJob
  include Loggable

  queue_as :default

  RECENT_REQUEST_WINDOW = 10.minutes

  def perform(waha_session_id)
    session = WahaSession.find_by(id: waha_session_id)
    return unless session
    return if session.working?

    user = session.user
    return unless user.provider == "phone" && user.uid.present?

    requested_at = nil
    user.with_lock do
      state = user.conversation_state || {}
      requested_at = parse_time(state["pairing_code_requested_at"])
      return unless state["stage"] == "waiting_for_connection"
      return unless requested_at && requested_at > RECENT_REQUEST_WINDOW.ago

      # Um aviso por código pedido
      notified_at = parse_time(state["pairing_code_expired_notified_at"])
      return if notified_at && notified_at >= requested_at

      user.update!(conversation_state: state.merge("pairing_code_expired_notified_at" => Time.current.iso8601))
    end

    Meta::Service.new(recipient: user.uid).send_list_message(
      body_text:   I18n.t("whatsapp_notices.pairing_code_expired.body"),
      button_text: I18n.t("whatsapp_notices.pairing_code_expired.button"),
      sections: [
        {
          title: I18n.t("whatsapp_notices.pairing_code_expired.section"),
          rows: [
            { id: "menu_connect", title: I18n.t("whatsapp_notices.pairing_code_expired.new_code"), description: I18n.t("whatsapp_notices.pairing_code_expired.new_code_description") },
            { id: "cancel_connection", title: I18n.t("whatsapp_notices.pairing_code_expired.cancel"), description: I18n.t("whatsapp_notices.pairing_code_expired.cancel_description") }
          ]
        }
      ]
    )

    log_info "Aviso de código de pareamento expirado enviado",
      event: "pairing_code_expired_notice_sent",
      user_id: user.id,
      waha_session_id: session.id,
      pairing_code_requested_at: requested_at.iso8601
  end

  private

  def parse_time(value)
    Time.zone.parse(value.to_s) if value.present?
  rescue ArgumentError
    nil
  end
end
