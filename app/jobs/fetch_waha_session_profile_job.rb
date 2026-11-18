class FetchWahaSessionProfileJob < ApplicationJob
  queue_as :default

  def perform(waha_session_id)
    session = WahaSession.find_by(id: waha_session_id)
    return unless session&.working?

    session.sync_profile! if session.waha_chat_id.blank?
    return if session.waha_chat_id.blank?

    url = session.waxum.profile_picture_url(session.waha_chat_id)
    session.update!(avatar_url: url) if url.present?
  rescue => e
    Rails.logger.warn "[FetchWahaSessionProfileJob] #{e.message}"
    Sentry.capture_exception(e)
  end
end
