class ExternalEvents::WhatsappProcessor < ExternalEvents::Base
  # MIME types that indicate an audio message.
  AUDIO_MIMETYPES = %w[
    audio/ogg audio/mpeg audio/mp4 audio/wav audio/webm audio/aac audio/opus
  ].freeze

  # Any emoji reaction will trigger transcription when the user reacts to a message.
  def process(worker_type: :waxum)
    @data = parse_payload(worker_type)
    @external_event.update!(parsed_event: @data)

    # Se for da META, só manda pro Reply — exceto áudio, que entra no mesmo
    # pipeline de transcrição do fluxo conectado (mesma cota, mesmo plano).
    if worker_type == :meta
      return unless @data[:event] == "message"

      payload = @data[:payload]

      if audio_message?(payload)
        enqueue_direct_transcription(payload)
        return
      end

      Reply::Base.new(
        from: payload[:from],
        display_name: payload[:display_name],
        message: payload[:body]
      ).reply(
        message: payload[:body],
        interactive_reply: payload[:interactive_reply],
        message_id: payload[:message_id],
        sent_at: payload[:created_at],
        metadata: {
          event: @data[:event],
          provider: @external_event.provider,
          has_media: payload[:hasMedia]
        }
      )
      return
    end

    return unless preprocess

    case @data[:event]
    when "session.status"
      process_session_status
    when "message"
      process_incoming_message
    when "message.reaction"
      process_reaction
    else
      log_warning "Evento desconhecido: #{@data[:event]}"
    end
  end

  private

  # ── Pre-processing: resolve the WahaSession from the session name ──────

  def preprocess
    log_info "Webhook: session=#{@data[:session]} event=#{@data[:event]}"

    @external_event.update!(event_type: @data[:event])

    @waha_session = WahaSession.find_by(session_name: @data[:session])
    if @waha_session.nil?
      log_warning "Nenhuma WahaSession encontrada para session=#{@data[:session]}"
      return false
    end

    true
  end

  # ── session.status ────────────────────────────────────────────────────

  def process_session_status
    status = @data.dig(:payload, :status).to_s

    # O WhatsApp recusou a versão do cliente: todas as sessões caem e só
    # atualizar o Waxum resolve. Não é culpa do usuário, então não mexe no
    # status (não dispara aviso de desconexão).
    if @data.dig(:payload, :raw_event) == "client_outdated"
      log_error "Waxum: cliente desatualizado (client_outdated) na sessão #{@waha_session.session_name}"
      Sentry.capture_message("Waxum client_outdated", extra: { session: @waha_session.session_name })
      return
    end

    # Os eventos de conexão não trazem o número: busca na sessão. Gravar o
    # número antes do status deixa o aviso de "conectado" (complete_user_onboarding)
    # com o destinatário certo.
    # Código de pareamento que expirou derruba o socket (disconnected): para
    # o app isso é falha do pareamento, não queda de conexão.
    status = "failed" if status == "starting" && @waha_session.scan_qr_code?

    @waha_session.sync_profile! if status == "working"
    @waha_session.update!(waha_status: status) if WahaSession.waha_statuses.key?(status)

    log_info "WahaSession #{@waha_session.id} → status=#{status} chat_id=#{@waha_session.waha_chat_id}"
  end

  # ── message / message.any ─────────────────────────────────────────────

  # Todo áudio é guardado com as chaves da mídia: no modo reação ele só é
  # transcrito quando o dono reagir a ele.
  def process_incoming_message
    payload = @data[:payload]

    unless audio_message?(payload)
      log_info "Mensagem ignorada: não é áudio (hasMedia=#{payload[:hasMedia]})"
      return
    end

    audio = store_audio_message(payload)
    return if audio.nil?

    if @waha_session.mode_reaction?
      log_info "Áudio guardado (modo reação): aguardando reação"
      return
    end

    enqueue_transcription(audio)
  end

  # ── message.reaction ──────────────────────────────────────────────────

  def process_reaction
    payload = @data[:payload]

    unless @waha_session.mode_reaction?
      log_info "Reação ignorada: sessão não está em modo reação"
      return
    end

    unless payload[:fromMe]
      log_info "Reação ignorada: não é do dono do número"
      return
    end



    message_id = payload[:reply_to_id]

    # Reação removida chega com emoji vazio.
    if message_id.blank? || payload[:body].blank?
      log_info "Reação ignorada: sem mensagem alvo ou reação removida"
      return
    end

    # Avoid re-transcribing the same audio if it was already requested.
    if Transcription.exists?(waha_message_id: message_id,
                             monitored_contact: @waha_session.monitored_contacts)
      log_info "Reação ignorada: já existe transcription para message=#{message_id}"
      return
    end

    # Só áudios que chegaram pelo webhook são conhecidos: reação em texto,
    # foto etc. (ou em áudio de antes da conexão) não acha nada.
    audio = @waha_session.audio_messages.find_by(message_id: message_id)
    if audio.nil?
      log_info "Reação ignorada: mensagem #{message_id} não é um áudio conhecido"
      return
    end

    enqueue_transcription(audio)
  end

  def store_audio_message(payload)
    media = payload[:media]
    @waha_session.audio_messages.create_or_find_by!(message_id: payload[:message_id]) do |audio|
      audio.chat_jid        = payload[:chat_jid]
      audio.phone           = payload[:phone]
      audio.from_me         = payload[:fromMe]
      audio.mimetype        = media[:mimetype]
      audio.seconds         = media[:seconds]
      audio.direct_path     = media[:direct_path]
      audio.media_key       = media[:media_key]
      audio.file_sha256     = media[:file_sha256]
      audio.file_enc_sha256 = media[:file_enc_sha256]
      audio.file_length     = media[:file_length]
    end
  rescue ActiveRecord::RecordInvalid => e
    log_warning "Áudio sem chaves de mídia (message=#{payload[:message_id]}): #{e.message}"
    nil
  end

  # Shared pipeline: given a stored audio, resolve the contact (auto-creating
  # one when needed) and queue the transcription job.
  def enqueue_transcription(audio)
    from_me = audio.from_me
    phone   = audio.phone
    chat_id = "#{phone}@c.us"

    # A conversa com o bot já é transcrita pelo fluxo direto (Meta). Transcrever
    # de novo pela sessão conectada gasta cota em dobro e manda o placeholder
    # para o bot, que o trata como pergunta e repassa para o time.
    if phone == BOT_PHONE_NUMBER
      log_info "Áudio ignorado: conversa com o próprio bot"
      return
    end

    contact = resolve_or_auto_create_contact(phone, chat_id, from_me: from_me)
    return if contact.nil?

    # Respect per-contact direction preference (only meaningful in
    # monitored_contacts mode — auto-created contacts in reaction mode are
    # always :both, so these guards are inert there).
    if from_me && contact.incoming?
      log_info "Áudio próprio ignorado (contato configurado como incoming)"
      return
    end

    if !from_me && contact.outgoing?
      log_info "Áudio do contato ignorado (contato configurado como outgoing)"
      return
    end

    log_info "Criando transcription: contact=#{contact.id} message=#{audio.message_id}"

    direction = from_me ? "outgoing" : "incoming"

    transcription = Transcription.create!(
      monitored_contact: contact,
      audio_message:     audio,
      waha_message_id:   audio.message_id,
      direction:         direction,
      status:            :processing
    )

    ActiveRecord.after_all_transactions_commit do
      TranscribeAudioJob.perform_later(transcription.id)
    end
  end

  # ── Direct chat with the bot (Meta) ────────────────────────────────────

  # A user sending audio straight to the EscreveZap number. Resolves/creates
  # the same WahaSession used for onboarding (Reply::Base) so the quota pool
  # is shared with the connected-flow, then queues the same TranscribeAudioJob.
  def enqueue_direct_transcription(payload)
    phone   = payload[:from].to_s.split("@").first
    session = WahaSession.find_or_create_for_phone!(phone: phone, display_name: payload[:display_name])
    contact = resolve_direct_chat_contact(session, phone)

    transcription = Transcription.create!(
      monitored_contact: contact,
      waha_message_id:   payload[:message_id],
      direction:          :incoming,
      channel:            :direct,
      media_id:           payload.dig(:media, :media_id),
      status:             :processing
    )

    ActiveRecord.after_all_transactions_commit do
      TranscribeAudioJob.perform_later(transcription.id)
    end
  end

  # One MonitoredContact per WahaSession represents "the conversation with the
  # bot itself" — mirrors the auto-created contacts used in reaction mode, just
  # hidden from the user-facing contact list.
  def resolve_direct_chat_contact(waha_session, phone)
    waha_session.monitored_contacts.find_or_create_by!(phone_number: phone) do |c|
      c.waha_chat_id = "#{phone}@c.us"
      c.direction    = :both
      c.enabled      = true
      c.auto_created = true
    end
  end

  # ── Helpers ───────────────────────────────────────────────────────────

  def audio_message?(payload)
    return false unless payload[:hasMedia]

    mimetype = payload.dig(:media, :mimetype).to_s
    mimetype.start_with?("audio/") || AUDIO_MIMETYPES.include?(mimetype)
  end

  # Look up the MonitoredContact by phone number or waha_chat_id.
  # Update waha_chat_id in the record if we discovered it here.
  def resolve_monitored_contact(phone, chat_id)
    contact = @waha_session.monitored_contacts.enabled
                           .find_by(phone_number: phone)
                           .presence ||
              @waha_session.monitored_contacts.enabled
                           .find_by(waha_chat_id: chat_id)

    if contact && contact.waha_chat_id.blank?
      contact.update_columns(waha_chat_id: chat_id)
    end

    contact
  end

  # Resolve an existing monitored contact or, when allowed, create one on the
  # fly so the standard pipeline can proceed unchanged. Returns nil when the
  # audio should be discarded.
  def resolve_or_auto_create_contact(phone, chat_id, from_me:)
    contact = resolve_monitored_contact(phone, chat_id)
    return contact if contact.present?

    # Reaction mode always auto-creates a contact (the user explicitly asked
    # for the transcription by reacting). The contact is flagged auto_created
    # so it stays out of the user-facing contact list.
    if @waha_session.mode_reaction?
      log_info "Modo reação: criando contato automático para #{chat_id}"
      contact = @waha_session.monitored_contacts.create!(
        phone_number: phone,
        waha_chat_id: chat_id,
        direction:    :both,
        enabled:      true,
        auto_created: true
      )
      FetchMonitoredContactProfilePictureJob.perform_later(contact.id)
      return contact
    end

    # monitored_contacts mode — fall back to the legacy auto_transcribe setting
    auto = @waha_session.auto_transcribe
    if auto == "never"
      log_info "Contato #{chat_id} não monitorado — descartando"
      return nil
    end

    # Early-exit for direction mismatches before touching the DB
    if auto == "incoming" && from_me
      log_info "Auto-transcribe (incoming): áudio próprio ignorado para #{chat_id}"
      return nil
    end
    if auto == "outgoing" && !from_me
      log_info "Auto-transcribe (outgoing): áudio de contato ignorado para #{chat_id}"
      return nil
    end

    log_info "Auto-transcribe (#{auto}): criando contato automático para #{chat_id}"

    contact = @waha_session.monitored_contacts.create!(
      phone_number:  phone,
      waha_chat_id:  chat_id,
      direction:     auto,
      enabled:       true
    )

    FetchMonitoredContactProfilePictureJob.perform_later(contact.id)
    contact
  end

  def parse_payload(worker_type)
    parser_class = case worker_type.to_sym
    when :meta then ExternalEvents::WhatsappParsers::MetaParser
    else            ExternalEvents::WhatsappParsers::WaxumParser
    end
    parser_class.new(@data).parse
  end
end
