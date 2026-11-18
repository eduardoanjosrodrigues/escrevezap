require "openssl"

# Webhook do gateway Waxum. Assinado com HMAC-SHA256 sobre
# "<timestamp>.<corpo>" (X-Webhook-Signature: sha256=<hex>,
# X-Webhook-Timestamp). Só guarda o que o app usa: eventos de conexão,
# áudios e reações em conversas individuais; o resto (textos, recibos,
# grupos) volta 200 e é descartado.
class Webhook::WaxumController < WebhookController
  SIGNATURE_TOLERANCE = 5.minutes
  MESSAGE_TYPES = %w[audio ptt reaction].freeze

  def create
    return head :unauthorized unless valid_signature?

    payload = JSON.parse(request.raw_post)
    return head :ok unless relevant?(payload)

    ExternalEvent.create!(provider: :waxum, data: payload).enqueue_processing
    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def relevant?(payload)
    return true unless payload["event"] == "message"

    data = payload["data"] || {}
    MESSAGE_TYPES.include?(data["message_type"]) && !data["is_group"] &&
      !data["chat"].to_s.start_with?("status@")
  end

  def valid_signature?
    signature = request.headers["X-Webhook-Signature"].to_s.delete_prefix("sha256=")
    timestamp = request.headers["X-Webhook-Timestamp"].to_s
    return false if signature.blank? || timestamp.blank?
    return false if (Time.current.to_i - timestamp.to_i).abs > SIGNATURE_TOLERANCE

    expected = OpenSSL::HMAC.hexdigest("SHA256", Waxum::Client.webhook_secret, "#{timestamp}.#{request.raw_post}")
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end
end
