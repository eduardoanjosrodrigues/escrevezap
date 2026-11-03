# Pacote avulso: pagamento único por Pix comum (cob), sem assinatura.
# Enquanto o usuário Grátis tem saldo de pacote, ele transcreve como o Pro
# (formatação com IA, áudios de até 25 min). Só o último pacote pago conta:
# o saldo é `credits` menos o que foi transcrito desde `paid_at`, e quem
# compra outro leva o saldo que sobrou (ver #mark_paid!). Pacote não vence.
class AudioPack < ApplicationRecord
  CREDITS = 40
  PRICE   = 9.99
  # O Pix do pacote vale 24h (o da assinatura, 1h).
  PIX_EXPIRATION = 24.hours.to_i

  belongs_to :user

  enum :status, { pending: "pending", paid: "paid" }, default: :pending

  # Idempotente: o webhook do Inter pode chegar repetido e o "Já paguei"
  # também confirma consultando a cobrança.
  def mark_paid!
    granted = nil

    with_lock do
      return false if paid?

      # Saldo de agora (grátis ou de um pacote anterior) vai junto.
      granted = CREDITS + (user.free? ? user.transcription_credits_remaining : 0)
      update!(status: :paid, paid_at: Time.current, credits: granted)
    end

    UsageEvent.track(user: user, event_type: UsageEvent::PACK_PURCHASED,
                     metadata: { audio_pack_id: id, price: price.to_f, credits: granted })
    Rails.logger.info(event: "audio_pack_paid", user_id: user_id, audio_pack_id: id, credits: granted)

    user.notify(
      subject: "Pagamento confirmado - pacote de transcrições",
      text: "✅ *Pagamento confirmado!*\n\n" \
            "Você tem *#{granted} transcrições* com formatação e resumo com IA, sem prazo para usar. " \
            "É só me encaminhar os áudios. 🚀"
    )
    true
  end
end
