module Admin
  class UpcomingPaymentsController < Admin::BaseController
    STATUSES = %w[active past_due trialing].freeze
    PROBLEM_STAGES = %i[missing_cobr cobr_failed overdue no_date].freeze

    def index
      @today = Date.current

      @subscriptions = Subscription.includes(:user)
                                   .where(status: STATUSES)
                                   .order(Arel.sql("next_charge_date ASC NULLS FIRST"), :id)
                                   .to_a
      @stages = @subscriptions.to_h { |s| [ s.id, s.billing_stage(@today) ] }

      @due_7d_amount  = due_amount(@today + 7)
      @due_30d_amount = due_amount(@today + 30)
      @in_window      = @stages.values.count(:in_window)
      @problems       = @stages.values.count { |stage| PROBLEM_STAGES.include?(stage) }

      # Previsão por mês: cada assinatura ativa repete o ciclo a partir da âncora.
      months = 0.upto(2).map { |n| (@today >> n).beginning_of_month }
      @forecast = months.index_with do |month|
        @subscriptions.sum do |s|
          next 0 if s.billing_anchor_date.blank?
          s.price * upcoming_dues(s, @today, month.end_of_month).count { |d| d.beginning_of_month == month }
        end
      end

      @recently_ended = Subscription.includes(:user)
                                    .where(status: %w[cancelled expired])
                                    .where(updated_at: 30.days.ago..)
                                    .order(updated_at: :desc)
    end

    private

    def due_amount(until_date)
      @subscriptions.select { |s| s.next_charge_date && s.next_charge_date <= until_date }.sum(&:price)
    end

    # Vencimentos de hoje até `until_date`, começando pelo próximo ainda em aberto.
    def upcoming_dues(subscription, from, until_date)
      first = subscription.next_charge_date || subscription.next_due_date_after(from)
      dues = [ first ]
      dues << subscription.next_due_date_after(dues.last) while dues.last < until_date
      dues.select { |d| d <= until_date }
    end
    helper_method :upcoming_dues
  end
end
