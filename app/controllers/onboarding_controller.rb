class OnboardingController < ApplicationController
  layout "auth"
  before_action :authenticate_user!
  before_action :redirect_if_completed, only: [:show, :reconnect]
  before_action :load_or_build_waha_session, only: [:show, :reconnect]

  # A conexão é feita pelo código de pareamento (WahaSessionsController#pairing_code).
  def show
    return unless @waha_session.working?

    current_user.update!(onboarding_completed: true, contacts_intro_dismissed: true) unless current_user.onboarding_completed?
    redirect_to authenticated_root_path
  end

  def reconnect
    begin
      @waha_session.reconnect!
      render json: { status: @waha_session.reload.waha_status }
    rescue => e
      render json: { error: "Não foi possível reconectar: #{human_error_message(e)}" }, status: :service_unavailable
      Sentry.capture_exception(e)
    end
  end

  def skip_connection
    current_user.update!(
      onboarding_completed: true,
      contacts_intro_dismissed: true
    )

    redirect_to authenticated_root_path, notice: "Você pode conectar seu WhatsApp depois, na aba WhatsApp."
  end

  private

  def load_or_build_waha_session
    @waha_session = current_user.waha_session || current_user.build_waha_session
    @waha_session.save! if @waha_session.new_record?
  end

  def human_error_message(error)
    message = error.message.to_s
    return "Tente novamente em alguns segundos." if message.blank?

    message
  end

  def redirect_if_completed
    redirect_to authenticated_root_path if current_user.onboarding_completed?
  end

  def contact_params
    params.require(:monitored_contact).permit(:phone_number, :display_name, :direction, :enabled)
  end

  def waha_session
    @waha_session ||= current_user.waha_session
  end
end
