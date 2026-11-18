class MonitoredContactsController < ApplicationController
  layout "authenticated"
  before_action :authenticate_user!
  before_action :ensure_monitored_contacts_mode!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_contact, only: [:edit, :update, :destroy]

  def index
    @transcription_mode = waha_session&.transcription_mode || "reaction"
    @contacts = waha_session.monitored_contacts.user_visible.order(:display_name, :phone_number)
  end

  def new
    @contact = waha_session.monitored_contacts.build
  end

  # GET /app/monitored_contacts/whatsapp_contacts.json
  def whatsapp_contacts
    unless waha_session&.working?
      render json: { contacts: [] } and return
    end

    raw = waha_session.waxum.contacts.select { |c| c["jid"].to_s.end_with?("@s.whatsapp.net") }
    contacts = raw.map do |c|
      phone = c["phone"].presence || c["jid"].to_s.split("@").first
      name  = c["full_name"].presence || c["push_name"].presence
      { phone: phone, name: name, label: [name, phone].compact.join(" · ") }
    end.sort_by { |c| c[:name].to_s.downcase }

    render json: { contacts: contacts }
  rescue => e
    render json: { contacts: [], error: e.message }
  end

  def create
    @contact = waha_session.monitored_contacts.build(contact_params)
    if @contact.save
      FetchMonitoredContactProfilePictureJob.perform_later(@contact.id)
      current_user.update!(contacts_intro_dismissed: true) unless current_user.contacts_intro_dismissed?
      redirect_to monitored_contacts_path, notice: "Contato adicionado!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @contact.update(contact_params)
      redirect_to monitored_contacts_path, notice: "Contato atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @contact.soft_delete!
    redirect_to monitored_contacts_path, notice: "Contato removido."
  end

  # POST /app/monitored_contacts/switch_mode
  # Toggle (or set) the transcription mode of the session.
  def switch_mode
    mode = params[:transcription_mode].to_s
    unless WahaSession.transcription_modes.key?(mode)
      redirect_to monitored_contacts_path, alert: "Modo inválido." and return
    end

    waha_session.update!(transcription_mode: mode)

    notice = if waha_session.mode_reaction?
               "Pronto! Reaja com 👀 em qualquer áudio para transcrever."
             else
               "Modo alterado. Adicione contatos para monitorar."
             end

    redirect_to monitored_contacts_path, notice: notice
  end

  private

  def set_contact
    @contact = waha_session.monitored_contacts.find(params[:id])
  end

  def contact_params
    params.require(:monitored_contact).permit(:phone_number, :display_name, :direction, :enabled)
  end

  def waha_session
    @waha_session ||= current_user.waha_session
  end

  def ensure_monitored_contacts_mode!
    return if waha_session&.mode_monitored_contacts?

    redirect_to monitored_contacts_path,
                alert: "Ative o modo de contatos monitorados para gerenciar contatos."
  end
end
