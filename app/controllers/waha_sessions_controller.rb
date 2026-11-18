class WahaSessionsController < ApplicationController
  layout "authenticated"
  before_action :authenticate_user!
  before_action :load_or_build_session

  # GET /app/waha_session — chip management page (post-onboarding)
  def show
  end

  # GET /app/waha_session/status  (JSON)
  def status
    render json: { status: @waha_session&.waha_status || "pending" }
  end

  # POST /app/waha_session/pairing_code  (JSON)
  def pairing_code
    phone = params[:phone_number].to_s.gsub(/\D/, "")

    if phone.blank?
      render json: { error: "Número de telefone inválido" }, status: :unprocessable_entity
      return
    end

    @waha_session.save! if @waha_session.new_record?
    render json: { code: @waha_session.request_pairing_code(phone) }
  rescue => e
    Sentry.capture_exception(e)
    render json: { error: "Aguarde alguns segundos e tente novamente. (#{e.message})" }, status: :service_unavailable
  end

  # POST /app/waha_session/reconnect
  def reconnect
    begin
      @waha_session.reconnect!
      respond_to do |format|
        format.html { redirect_to app_waha_session_path, notice: "Reconectando WhatsApp..." }
        format.json { render json: { status: @waha_session.waha_status } }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to app_waha_session_path, alert: "Erro ao reconectar: #{e.message}" }
        format.json { render json: { error: "Erro ao reconectar: #{e.message}" }, status: :service_unavailable }
      end
    end
  end

  # DELETE /app/waha_session
  def destroy
    @waha_session.disconnect!
    redirect_to app_waha_session_path, notice: "WhatsApp desconectado."
  end

  private

  def load_or_build_session
    @waha_session = current_user.waha_session || current_user.build_waha_session
  end
end
