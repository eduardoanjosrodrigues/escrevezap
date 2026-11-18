# Pareamento por código: o Waxum não manda o evento connected quando o código
# é aceito (só pair_success, que não dá para assinar no webhook). Então,
# depois de pedir o código, conferimos o estado ao vivo até a sessão logar
# ou o código expirar (~3 min).
class WahaSessionPairingCheckJob < ApplicationJob
  include Loggable

  queue_as :default

  INTERVAL   = 10.seconds
  MAX_CHECKS = 24

  def perform(waha_session_id, check = 1)
    session = WahaSession.find_by(id: waha_session_id)
    return if session.nil? || session.working?

    if session.waxum.status["is_logged_in"]
      session.sync_profile!
      session.update!(waha_status: :working)
      log_info "Pareamento concluído: sessão #{session.session_name}"
    elsif check < MAX_CHECKS
      self.class.set(wait: INTERVAL).perform_later(waha_session_id, check + 1)
    end
  rescue ApiRequest::ApiError => e
    log_warning "Falha ao conferir pareamento da sessão #{waha_session_id}: #{e.message}"
    self.class.set(wait: INTERVAL).perform_later(waha_session_id, check + 1) if check < MAX_CHECKS
  end
end
