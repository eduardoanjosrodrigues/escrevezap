class FetchMonitoredContactProfilePictureJob < ApplicationJob
  queue_as :default

  def perform(monitored_contact_id)
    contact = MonitoredContact.find_by(id: monitored_contact_id)
    return unless contact

    waha_session = contact.waha_session
    return unless waha_session&.working?

    chat_id = contact.resolve_waha_chat_id

    fetch_avatar(contact, waha_session, chat_id)
    fetch_display_name(contact, waha_session, chat_id) if contact.display_name.blank?
  rescue => e
    Rails.logger.warn("[FetchMonitoredContactProfilePictureJob] contact=#{monitored_contact_id} #{e.class}: #{e.message}")
    Sentry.capture_exception(e)
  end

  private

  def fetch_avatar(contact, waha_session, chat_id)
    url = waha_session.waxum.profile_picture_url(chat_id)
    contact.update_column(:avatar_url, url) if url.present?
  rescue => e
    Rails.logger.warn("[FetchMonitoredContactProfilePictureJob] avatar fetch failed for contact=#{contact.id}: #{e.message}")
    Sentry.capture_exception(e)
  end

  def fetch_display_name(contact, waha_session, chat_id)
    phone = chat_id.split("@").first
    match = waha_session.waxum.contacts.find { |c| c["phone"] == phone || c["jid"].to_s.start_with?("#{phone}@") }
    return unless match

    name = match["full_name"].presence || match["push_name"].presence
    contact.update_column(:display_name, name) if name.present?
  rescue => e
    Rails.logger.warn("[FetchMonitoredContactProfilePictureJob] display_name fetch failed for contact=#{contact.id}: #{e.message}")
    Sentry.capture_exception(e)
  end
end
