module Billing
  # Handles AbacatePay webhook events and syncs subscription/plan state.
  class EventHandler
    def initialize(billing_event)
      @event     = billing_event
      @payload   = billing_event.payload
      @sub_data  = @payload.dig("data", "subscription") || {}
      @cust_data = @payload.dig("data", "customer") || {}
    end

    def process!
      case @event.event_type
      when "subscription.trial_started" then handle_trial_started
      when "subscription.completed"     then handle_completed
      when "subscription.renewed"       then handle_renewed
      when "subscription.cancelled"     then handle_cancelled
      when "subscription.plan_changed"  then handle_plan_changed
      end
    end

    private

    # Resolves the User from the externalId we set at checkout creation.
    # Format: "user_<user_id>:<plan>"
    def resolve_user
      external_id = @payload.dig("data", "checkout", "externalId").to_s
      user_id     = external_id.split(":").first&.gsub("user_", "")&.to_i
      User.find_by(id: user_id)
    end

    # Maps the product_id in the checkout to a plan name.
    def resolve_plan
      product_id = @payload.dig("data", "checkout", "items", 0, "id").to_s
      basic_id   = Rails.application.credentials.dig(:abacatepay, :product_basic_id).to_s
      pro_id     = Rails.application.credentials.dig(:abacatepay, :product_pro_id).to_s

      case product_id
      when pro_id   then "pro"
      when basic_id then "basic"
      else               "basic"
      end
    end

    def find_or_build_subscription(user)
      user.subscription || user.build_subscription
    end

    def handle_trial_started
      user = resolve_user
      return unless user

      plan         = resolve_plan
      subscription = find_or_build_subscription(user)

      subscription.update!(
        status:                     :trialing,
        plan:                       plan,
        abacatepay_subscription_id: @sub_data["id"],
        abacatepay_customer_id:     @cust_data["id"],
        trial_ends_at:              @sub_data["trialEndsAt"],
        current_period_start:       Time.current,
        current_period_end:         @sub_data["trialEndsAt"]
      )
      user.update!(plan: plan)
    end

    def handle_completed
      user = resolve_user
      return unless user

      plan         = resolve_plan
      new_sub_id   = @sub_data["id"]
      existing_sub = user.subscription

      # If upgrading from an existing active subscription, cancel the old one in AbacatePay
      if existing_sub&.active_or_trialing? && existing_sub.abacatepay_subscription_id != new_sub_id
        begin
          Abacatepay::Client.new.subscriptions.cancel(id: existing_sub.abacatepay_subscription_id)
        rescue => e
          Rails.logger.error "[Billing::EventHandler#handle_completed] Cancel old sub failed: #{e.message}"
          Sentry.capture_exception(e)
        end
      end

      subscription = existing_sub || user.build_subscription
      subscription.update!(
        status:                     :active,
        plan:                       plan,
        abacatepay_subscription_id: new_sub_id,
        abacatepay_customer_id:     @cust_data["id"],
        current_period_start:       Time.current,
        current_period_end:         1.month.from_now,
        trial_ends_at:              nil,
        cancelled_at:               nil
      )
      user.update!(plan: plan)

      plan_name = plan.to_s.humanize
      user.notify(
        subject: "Pagamento confirmado - plano #{plan_name} ativo",
        text: "🎉 *Pagamento Confirmado!*\n\n" \
              "Deu tudo certo! Sua assinatura do plano *#{plan_name}* está ativa.\n\n" \
              "Seu limite de transcrições foi atualizado e você já pode voltar a transcrever seus áudios normalmente. " \
              "Muito obrigado pela confiança! 🚀"
      )
    end

    def handle_renewed
      subscription = Subscription.find_by(abacatepay_subscription_id: @sub_data["id"])
      return unless subscription

      subscription.update!(
        status:               :active,
        current_period_start: Time.current,
        current_period_end:   1.month.from_now
      )

      # Apply any pending plan change that was scheduled (e.g. a downgrade)
      subscription.apply_pending_plan! if subscription.pending_downgrade?
    end

    def handle_cancelled
      subscription = Subscription.find_by(abacatepay_subscription_id: @sub_data["id"])
      return unless subscription

      subscription.update!(
        status:       :cancelled,
        cancelled_at: @sub_data["canceledAt"].presence || Time.current
      )
      subscription.user.update!(plan: :free)
    end

    def handle_plan_changed
      # AbacatePay fires this webhook immediately when change-plan is called —
      # even though the actual plan switch only happens on the next billing cycle.
      # So we store it as pending_plan and apply it when subscription.renewed fires.
      update_data = @payload["data"] || {}
      sub_id      = update_data["subscriptionId"].presence || @sub_data["id"]
      product_id  = update_data["productId"].to_s

      subscription = Subscription.find_by(abacatepay_subscription_id: sub_id)
      return unless subscription

      basic_id = Rails.application.credentials.dig(:abacatepay, :product_basic_id).to_s
      pro_id   = Rails.application.credentials.dig(:abacatepay, :product_pro_id).to_s

      new_plan = case product_id
                 when pro_id   then "pro"
                 when basic_id then "basic"
                 end
      return unless new_plan

      # Only schedule as pending — do NOT touch subscription.plan or user.plan yet.
      # handle_renewed will apply it at the start of the next billing cycle.
      subscription.update!(pending_plan: new_plan)
      Rails.logger.info "[Billing::EventHandler] Plan change scheduled: sub #{sub_id} → #{new_plan} (pending, takes effect next cycle)"
    end
  end
end
