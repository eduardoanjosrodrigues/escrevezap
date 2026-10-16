class BillingController < ApplicationController
  layout "authenticated"
  before_action :authenticate_user!

  def show
    @subscription = current_user.subscription
  end

  # GET /app/assinatura/cancelar — modal
  def cancel_confirm
    @subscription = current_user.subscription
    render layout: false
  end

  # DELETE /app/assinatura/cancelar
  def cancel
    subscription = current_user.subscription

    unless subscription&.active_or_trialing?
      redirect_to billing_path, alert: "Você não possui uma assinatura ativa." and return
    end

    if subscription.cancel!
      redirect_to billing_path, notice: "Assinatura cancelada. Acesso ao plano gratuito a partir de agora."
    else
      redirect_to billing_path, notice: "Assinatura cancelada. Se o débito automático continuar ativo, cancele pelo app do seu banco."
    end
  rescue => e
    Rails.logger.error "[BillingController#cancel] #{e.message}"
    Sentry.capture_exception(e)
    redirect_to billing_path, alert: "Erro ao cancelar. Tente novamente."
  end

  # GET /app/obrigado
  def success
    @plan = params[:plan].to_s
  end
end
