class ExternalEvent < ApplicationRecord
  # waha: eventos antigos, de antes da troca pelo Waxum (só histórico).
  enum :provider, {
    waxum: "waxum",
    waha: "waha",
    meta: "meta",
    inter: "inter"
  }, default: :waxum

  enum :status, { pending: "pending", completed: "completed", failed: "failed" }, default: :pending

  def process
    whatsapp_processor = ExternalEvents::WhatsappProcessor.new(self)
    case provider
    when "waxum"
      whatsapp_processor.process_event(worker_type: :waxum)
    when "meta"
      whatsapp_processor.process_event(worker_type: :meta)
    when "inter"
      inter_processor = Inter::WebhookProcessor.new(payload: self.data)
      inter_processor.call
    else
      raise "Unknown provider: #{provider}"
    end
  end

  def enqueue_processing
    ExternalEventProcessingJob.perform_later(self.id)
  end
end
