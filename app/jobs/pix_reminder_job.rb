# 2h depois de gerar o Pix da assinatura, se ainda não pagou, reenvia o código
# (consultado de novo no Inter) dentro da janela de 24h. Sem template: a Meta
# recusa como golpe avisos do tipo "pagamento pendente" fora da janela.
class PixReminderJob < BotNudgeJob
  KIND  = "pix_reminder".freeze
  DELAY = 2.hours

  def self.schedule(subscription)
    set(wait: DELAY).perform_later(subscription.id, subscription.inter_txid)
  end

  def perform(subscription_id, txid)
    subscription = Subscription.find_by(id: subscription_id)
    return unless subscription
    # pagou, cancelou ou gerou outro Pix depois deste
    return unless subscription.inactive? && subscription.inter_txid == txid

    user = subscription.user
    return unless reachable?(user)
    return if user.active_subscriber? || user.follow_up_sent?(KIND, since: 1.day.ago)
    return self.class.set(wait_until: next_morning).perform_later(subscription_id, txid) if quiet_hours?
    return unless user.whatsapp_window_open?

    plan = subscription.plan.to_s
    pix_code = current_pix_code(subscription)
    meta = Meta::Service.new(recipient: user.uid)

    if pix_code
      meta.send_message("Seu Pix da assinatura *#{plan.capitalize}* ainda está pendente. " \
                        "Se quiser concluir, o código está aqui embaixo 👇 Assim que pagar, o plano é ativado na hora.")
      meta.send_pix_code(reference_id: txid, pix_code: pix_code,
                         total_amount_cents: (Subscription::PRICES.fetch(plan, Subscription::PRICES["basic"]) * 100).round,
                         description: "Assinatura EscreveZap - #{plan.capitalize}")
    else
      meta.send_message_with_buttons("Seu Pix da assinatura *#{plan.capitalize}* não foi concluído. Quer gerar um novo?",
                                     [ { type: "reply", reply: { id: "upgrade_#{plan}:pix_reminder", title: "Gerar novo Pix" } } ])
    end

    record(user, KIND, :text, subscription_id: subscription.id, txid: txid, pix_resent: pix_code.present?)
  end

  private

  # O "copia e cola" da Jornada 3 sai da consulta da recorrência com o txid da
  # cobrança imediata (como no Inter::PixService.setup_automatic_pix).
  def current_pix_code(subscription)
    return nil if subscription.inter_recorrencia_id.blank?

    Inter::Service.new.get_recurrence(subscription.inter_recorrencia_id, txid: subscription.inter_txid)
                  .dig("dadosQR", "pixCopiaECola")
  rescue => e
    Rails.logger.warn(event: "pix_reminder_code_unavailable", subscription_id: subscription.id, error: e.message)
    nil
  end
end
