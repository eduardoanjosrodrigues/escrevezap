class ExternalEventProcessingJob < ApplicationJob
  def perform(external_event_id)
    external_event = ExternalEvent.find(external_event_id)
    external_event.process
    external_event.update_columns(status: :completed, error_message: nil, updated_at: Time.current)
  rescue ActiveRecord::RecordNotFound
    raise
  rescue => e
    external_event.update_columns(
      status:        :failed,
      error_message: "#{e.class}: #{e.message}".truncate(1000),
      retry_count:   external_event.retry_count + 1,
      updated_at:    Time.current
    )
    raise
  end
end
