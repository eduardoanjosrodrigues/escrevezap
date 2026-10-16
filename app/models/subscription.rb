class Subscription < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true, inclusion: { in: %w[inter] }

  enum :status, {
    inactive:  "inactive",
    trialing:  "trialing",
    active:    "active",
    past_due:  "past_due",
    cancelled: "cancelled",
    expired:   "expired"
  }, default: :inactive

  enum :plan, {
    basic: "basic",
    pro:   "pro"
  }, prefix: :sub

  PRICES = { "basic" => 5.99, "pro" => 19.90 }.freeze

  # Dias de tolerância após o vencimento antes de expirar (o Inter permite
  # retentativas por até 7 dias - PERMITE_3R_7D).
  GRACE_DAYS = 8

  scope :inter_recurring, -> { where(provider: "inter").where.not(inter_recorrencia_id: nil) }

  # Vencimento do ciclo `n` a partir do dia âncora. Date#>> já usa o último
  # dia válido do mês (31/01 -> 28/02), como a regra de ciclos do Pix Automático.
  def self.cycle_due_date(anchor, n)
    anchor >> n
  end

  # Primeiro vencimento estritamente depois de `date`.
  def next_due_date_after(date)
    n = 1
    n += 1 while self.class.cycle_due_date(billing_anchor_date, n) <= date
    self.class.cycle_due_date(billing_anchor_date, n)
  end

  def price
    PRICES.fetch(plan.to_s, PRICES["basic"])
  end

  def cobr_created_for_next_charge?
    inter_cobr_txid.present? && inter_cobr_due_date == next_charge_date
  end

  # Cancela o Pix Automático no Inter e a assinatura aqui. Retorna false se o
  # Inter falhou: a assinatura é cancelada localmente mesmo assim e o usuário
  # pode cancelar o débito pelo app do banco.
  def cancel!
    cancelled_at_inter = begin
      Inter::PixService.cancel_automatic_pix(inter_recorrencia_id) if inter_recorrencia_id.present?
      true
    rescue => e
      Rails.logger.error "[Subscription#cancel!] Inter error: #{e.message}"
      Sentry.capture_exception(e)
      false
    end

    update!(status: :cancelled, cancelled_at: Time.current)
    user.update!(plan: :free)
    cancelled_at_inter
  end

  def active_or_trialing?
    active? || trialing?
  end

  def current_period_active?
    current_period_end.present? && current_period_end > Time.current
  end

  def pending_downgrade?
    pending_plan.present?
  end

  def apply_pending_plan!
    return unless pending_plan.present?
    update!(plan: pending_plan, pending_plan: nil)
    user.update!(plan: pending_plan)
  end
end
