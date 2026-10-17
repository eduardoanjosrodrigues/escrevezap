class TranscribeAudioJob < ApplicationJob
  queue_as :default
  DEFAULT_AUDIO_EXTENSION = ".ogg".freeze

  # Threshold mínimo para rodar a formatação AI.
  AI_FORMAT_MIN_CHARS = 20

  # Transcrições com menos caracteres que este limiar não recebem resumo AI.
  # Precisa de pelo menos ~3-4 frases para um resumo agregar valor.
  AI_SUMMARY_MIN_CHARS = 350

  # Selects which STT engine to use. Defaults to deepgram.
  # Set credentials[:transcription_engine] = "gpt-4o-transcribe" to switch to OpenAI.
  TRANSCRIPTION_ENGINE = (Rails.application.credentials[:transcription_engine] || "deepgram").freeze

  # ── Prompts ────────────────────────────────────────────────────────────

  # "Polished" — texto refinado com resumo e formatação completa.
  AI_PROMPT_POLISHED = <<~PROMPT.freeze
    Você é um assistente especializado em MELHORAR transcrições de áudio do WhatsApp.

    Sua tarefa é pegar uma transcrição falada e transformá-la em uma mensagem de WhatsApp clara, organizada e agradável de ler.

    OBJETIVO:
    Manter exatamente o mesmo significado do áudio, mas melhorar bastante a apresentação do texto.

    REGRAS IMPORTANTES:

    - NÃO mude o significado
    - NÃO invente informações
    - NÃO resuma
    - NÃO transforme em algo corporativo
    - Preserve a intenção original
    - Preserve o tom informal quando fizer sentido

    VOCÊ DEVE:
    - melhorar clareza
    - organizar frases
    - corrigir gramática
    - adicionar pontuação
    - quebrar em parágrafos
    - remover vícios de fala excessivos
    - deixar o texto mais agradável de ler
    - reorganizar frases quando necessário

    O resultado deve parecer:

    "essa pessoa falou isso de forma clara no WhatsApp"

    EXEMPLO:

    ENTRADA:
    "aí a gente ainda pode botar uma opção extra que é passar em uma ia depois de transcrever pra melhorar o texto voce manda o audio falando assim de qualquer jeito"

    SAÍDA ESPERADA:
    "Aí a gente ainda pode colocar uma opção extra, que seria passar o texto por uma IA depois da transcrição, pra dar uma melhorada, né?

    Você manda o áudio do seu jeito, normalmente, e depois a IA organiza tudo, deixando o texto mais claro e bonitinho."

    Dado o texto transcrito abaixo, retorne um JSON com duas chaves:
    - "summary": Um resumo em UMA frase curta (máximo 120 caracteres) do ponto central
      da mensagem. O resumo DEVE ser substancialmente mais curto que o texto original.
      Se o texto for curto (menos de 3 frases distintas) ou se não for possível resumir
      sem perder o essencial, retorne null.
    - "full_formatted": A transcrição formatada de forma legível, corrigindo pontuação,
      paragrafando naturalmente e destacando termos importantes com *negrito*.
    Responda SOMENTE com o JSON válido, sem markdown, sem comentários.
  PROMPT

  # "WhatsApp" — imita como uma pessoa real escreveria o áudio no WhatsApp. Padrão.
  AI_PROMPT_WHATSAPP = <<~PROMPT.freeze
    Você é um assistente especializado em converter transcrições de áudio do WhatsApp em mensagens de texto do WhatsApp.

    Sua tarefa é reescrever o áudio transcrito exatamente como a própria pessoa escreveria essa mensagem no WhatsApp.

    OBJETIVO:
    O resultado deve parecer uma mensagem real de WhatsApp — natural, fluida, no estilo da pessoa.

    REGRAS:

    - Preserve o significado e o conteúdo completo
    - Preserve o tom, a informalidade e o jeito da pessoa
    - Use linguagem de WhatsApp: frases curtas, parágrafos pequenos (1-2 frases)
    - Corrija palavras claramente erradas pelo reconhecimento de voz
    - Adicione pontuação natural (vírgulas, reticências quando apropriado...)
    - Pode usar abreviações comuns do WhatsApp (tô, pra, né, vc, etc.)
    - Não use formatação markdown como **negrito** ou listas
    - Não transforme em texto profissional ou corporativo
    - Não resuma — mantenha todo o conteúdo
    - Não adicione informações que não estavam no áudio

    EXEMPLO:

    ENTRADA:
    "ei cara então sobre aquela ideia que a gente discutiu ontem eu tava pensando que talvez a gente pudesse tentar fazer diferente sabe tipo em vez de fazer tudo de uma vez podia ir por partes assim fica mais fácil de controlar e se der algum problema a gente consegue ajustar antes de ficar grande demais o que você acha"

    SAÍDA ESPERADA:
    "ei cara, sobre aquela ideia que a gente discutiu ontem...

    tava pensando que talvez desse pra fazer diferente, sabe? em vez de fazer tudo de uma vez, ir por partes.

    fica mais fácil de controlar, e se der algum problema a gente ajusta antes de virar bagunça grande.

    o que você acha?"

    Dado o texto transcrito abaixo, retorne um JSON com duas chaves:
    - "summary": Um resumo em UMA frase curta (máximo 120 caracteres) do ponto central
      da mensagem, escrito de forma direta e informal. Se o texto for curto (menos de
      3 frases distintas) ou se o conteúdo não comportar resumo sem perda, retorne null.
    - "full_formatted": O texto reescrito no estilo WhatsApp conforme as regras acima.
    Responda SOMENTE com o JSON válido, sem markdown, sem comentários.
  PROMPT

  # "Faithful" — o mais próximo do que foi dito, mínima intervenção AI.
  AI_PROMPT_FAITHFUL = <<~PROMPT.freeze
    Você é um assistente especializado em LIMPAR transcrições de áudio do WhatsApp.

    Sua tarefa é transformar uma transcrição falada em um texto mais legível, MAS preservando ao máximo o jeito original da pessoa falar.

    OBJETIVO:
    O texto deve parecer a mesma pessoa falando, só que um pouco mais organizado.

    REGRAS IMPORTANTES:

    - NÃO reescreva o conteúdo de forma profissional
    - NÃO mude o tom da pessoa
    - NÃO resuma
    - NÃO adicione informações
    - NÃO invente contexto
    - NÃO transforme em texto corporativo
    - NÃO deixe “bonito demais”
    - Preserve informalidade e espontaneidade
    - Preserve gírias e jeito de falar
    - Preserve hesitações quando fizer sentido
    - Corrija apenas o necessário para leitura ficar fluida

    VOCÊ PODE:
    - corrigir pontuação
    - separar parágrafos
    - remover repetições excessivas
    - melhorar levemente gramática
    - corrigir palavras claramente erradas da transcrição
    - deixar a leitura mais natural

    IMPORTANTE:
    Se a pessoa falou de forma bagunçada, mantenha um pouco dessa naturalidade.

    EXEMPLO:

    ENTRADA:
    "aí a gente ainda pode botar uma opção extra que é passar numa ia depois de transcrever pra melhorar o texto né voce manda o audio de qualquer jeito"

    SAÍDA ESPERADA:
    "Aí a gente ainda pode botar uma opção extra, que é passar numa IA depois de transcrever, pra dar uma melhorada no texto, né?

    Você manda o áudio de qualquer jeito mesmo, normal..."

    Dado o texto transcrito abaixo, retorne um JSON com duas chaves:
    - "summary": null
    - "full_formatted": O texto com erros óbvios de reconhecimento de voz corrigidos
      e pontuação básica adicionada. Preserve absolutamente o vocabulário, as expressões,
      o ritmo e o estilo de fala original. Não reformule, não reescreva, não resuma.
    Responda SOMENTE com o JSON válido, sem markdown, sem comentários.
  PROMPT

  # confirmed: o usuário já aceitou gastar créditos extras por um áudio acima
  # do limite de duração do plano (Reply::LongAudio).
  def perform(transcription_id, confirmed: false)
    transcription = Transcription.find(transcription_id)
    user          = transcription.monitored_contact.waha_session.user
    channel       = build_channel(transcription)

    # Guard: transport must be ready (e.g. Waha session connected)
    unless channel.ready?
      Rails.logger.warn "[TranscribeAudioJob] Canal não pronto para transcription #{transcription.id} — skipping"
      fail_transcription!(transcription, "Canal não pronto")
      return
    end

    # Guard: áudios por minuto (rajada de encaminhamentos)
    if !confirmed && rate_limited?(transcription, user)
      Rails.logger.info "[TranscribeAudioJob] Rate limit de #{User::TRANSCRIPTIONS_PER_MINUTE}/min atingido para user #{user.id} — skipping"
      fail_transcription!(transcription, "Limite de #{User::TRANSCRIPTIONS_PER_MINUTE} áudios por minuto atingido")
      TrackUsageJob.perform_later(user_id: user.id, event_type: UsageEvent::TRANSCRIPTION_RATE_LIMITED, metadata: { transcription_id: transcription.id })
      return
    end

    # Guard: limite do plano (Grátis: na vida; pagos: no mês)
    if user.transcription_limit_reached?(excluding: transcription, credits: transcription.credits)
      Rails.logger.info "[TranscribeAudioJob] Limite do plano atingido para user #{user.id} — skipping"
      send_limit_reached_notice(transcription, channel, user) if claim_limit_notice(transcription, user)
      fail_transcription!(transcription, "Limite de transcrições do plano atingido")
      return
    end

    # Guard: reaction trial limit (transcrição por reação é recurso Pro)
    if transcription.waha? && user.reaction_limit_reached?(excluding: transcription)
      Rails.logger.info "[TranscribeAudioJob] Limite de reação atingido para user #{user.id} — skipping"
      send_reaction_limit_notice(user)
      fail_transcription!(transcription, "Limite mensal de transcrições por reação atingido")
      return
    end

    process_transcription(transcription, channel, user, confirmed: confirmed)
  end

  private

  def build_channel(transcription)
    if transcription.direct?
      TranscriptionChannels::MetaDirectChannel.new(transcription)
    else
      TranscriptionChannels::WahaChannel.new(transcription)
    end
  end

  def process_transcription(transcription, channel, user, confirmed: false)
    unless transcription.media_url.present? || transcription.media_id.present?
      fail_transcription!(transcription, "URL de mídia ausente na mensagem")
      return
    end

    placeholder_message_id = nil
    stage = "send_whatsapp"

    # 0. Mark chat as read + send immediate progress feedback
    channel.mark_read
    placeholder_message_id = channel.send_placeholder("_⏳ Transcrevendo com o EscreveZap! Aguarde um instante..._")

    # 1. Download the audio binary (áudio longo confirmado já foi baixado e
    #    anexado na primeira passada — a URL da Meta pode ter expirado)
    stage = "download_audio"
    audio_data = attached_audio(transcription)
    if audio_data.nil?
      audio_data = channel.download_audio
      attach_audio(transcription, audio_data, transcription.media_url)
    end

    # 1b. Limite de duração do plano, checado antes de pagar o STT. Formatos
    #     que não são Ogg (duração desconhecida) passam.
    stage = "check_duration"
    duration = OggDuration.seconds(audio_data)
    if duration
      transcription.update!(audio_duration: duration)
      if !confirmed && duration > user.max_audio_duration
        handle_long_audio(transcription, channel, user, placeholder_message_id, duration)
        return
      end
    end

    # 2. Write to a temp file and transcribe
    stage = "stt"
    transcriber = nil
    transcript = Tempfile.create([ "wt_audio_#{transcription.id}", ".ogg" ], binmode: true) do |file|
      file.write(audio_data)
      file.flush
      transcriber = build_transcriber(file.path)
      text = transcriber.speech_to_text
      transcription.update!(audio_duration: transcriber.duration) if transcriber.duration
      text
    end

    if transcript.blank?
      fail_transcription!(transcription, "#{TRANSCRIPTION_ENGINE} retornou transcrição vazia")
      return
    end

    # Track STT provider cost
    track_transcription_usage(transcription, transcriber)

    # 3. AI formatting (Pro; demais planos têm AI_FORMAT_TRIAL_LIMIT por mês)
    stage = "ai_format"
    ai_token_count = nil
    if transcript.length >= AI_FORMAT_MIN_CHARS && user.can_ai_format?(excluding: transcription)
      with_summary = transcript.length >= AI_SUMMARY_MIN_CHARS
      summary, full_formatted, ai_token_count = ai_format(transcript, user, transcription, with_summary: with_summary)
    end
    track_openai_usage(transcription, ai_token_count) if ai_token_count

    # 4. Update the transcription record
    stage = "process"
    transcription.update!(
      transcript:     transcript,
      summary:        summary,
      full_formatted: full_formatted,
      status:         :completed
    )

    # 5. Send/finalize the transcription reply. No chat direto a entrega vai
    #    por um job próprio, que reenvia quando a Meta limita a rajada.
    stage = "send_whatsapp"
    if transcription.direct?
      SendTranscriptionReplyJob.perform_later(transcription.id)
    else
      channel.finalize(placeholder_message_id, transcription.reply_text(user))
      transcription.update!(reply_message_id: placeholder_message_id)
    end

    # 6. Track usage event (async, non-critical)
    metadata = { transcription_id: transcription.id, duration: transcriber&.duration, plan: user.plan }
    TrackUsageJob.perform_later(user_id: user.id, event_type: UsageEvent::TRANSCRIPTION_COMPLETED, metadata: metadata)
    if ai_token_count
      TrackUsageJob.perform_later(user_id: user.id, event_type: UsageEvent::AI_FORMAT_COMPLETED, metadata: { transcription_id: transcription.id, tokens: ai_token_count, plan: user.plan, trial: !user.pro? })
    end
  rescue => e
    Rails.logger.error "[TranscribeAudioJob] Erro ao processar transcription #{transcription.id} (stage=#{stage}): #{e.message}"
    record_error!(transcription, stage: stage, error: e)
    begin
      channel.finalize(placeholder_message_id, "❌ _Não foi possível transcrever este áudio. Tente novamente._")
    rescue => edit_error
      Rails.logger.warn "[TranscribeAudioJob] Falha ao notificar erro: #{edit_error.message}"
    end
    fail_transcription!(transcription, e.message)
    raise e
  end

  # ── AI Formatting ──────────────────────────────────────────────────────

  # Returns [summary, full_formatted, total_tokens]
  def ai_format(transcript, user, transcription, with_summary: true)
    prompt = if user.faithful?
               AI_PROMPT_FAITHFUL
    elsif user.polished?
               AI_PROMPT_POLISHED
    else
               AI_PROMPT_WHATSAPP
    end
    response = Llm::Client.new(model: "gpt-5.4-mini")
                          # Joga a verbosity e o thinking lá embaixo
                          .with_params(reasoning: { effort: "low" }, text: { verbosity: "low" })
                          .with_instructions(prompt)
                          .add_message(role: "user", content: transcript)
                          .complete

    result       = parse_llm_json(response.content)
    token_count  = (response.input_tokens.to_i + response.output_tokens.to_i).then { |n| n > 0 ? n : nil }
    summary      = with_summary ? result[:summary] : nil
    [ summary, result[:full_formatted], token_count ]
  rescue JSON::ParserError, KeyError => e
    Rails.logger.warn "[TranscribeAudioJob] AI format parse error: #{e.message}"
    Sentry.capture_exception(e)
    record_error!(transcription, stage: "ai_format", error: e)
    [ nil, nil, nil ]
  rescue => e
    Rails.logger.warn "[TranscribeAudioJob] AI format failed: #{e.message}"
    Sentry.capture_exception(e)
    record_error!(transcription, stage: "ai_format", error: e)
    [ nil, nil, nil ]
  end

  # Parses a JSON string returned by the LLM, handling two common failure modes:
  #   1. Markdown code fences wrapping the JSON (```json ... ```)
  #   2. Literal control characters (\n, \r, \t) inside string values — the JSON
  #      spec forbids them unescaped, but some model responses include them.
  def parse_llm_json(raw)
    cleaned = raw.to_s.strip
                 .delete_prefix("```json").delete_prefix("```")
                 .delete_suffix("```").strip

    JSON.parse(cleaned, symbolize_names: true)
  rescue JSON::ParserError
    JSON.parse(escape_control_chars_in_json_strings(cleaned), symbolize_names: true)
  end

  # Walks the JSON byte-by-byte and escapes control characters that appear
  # *inside* string values only, leaving structural whitespace untouched.
  def escape_control_chars_in_json_strings(json_str)
    result      = +""
    in_string   = false
    escape_next = false

    json_str.each_char do |c|
      if escape_next
        result << c
        escape_next = false
      elsif c == "\\"
        result << c
        escape_next = true
      elsif c == '"'
        result << c
        in_string = !in_string
      elsif in_string && c.match?(/[\x00-\x1f]/)
        # Encode the raw control char as its JSON escape sequence.
        result << c.ord.then { |o| "\\u%04x" % o }
      else
        result << c
      end
    end

    result
  end

  # ── Engine factory ────────────────────────────────────────────────────

  def build_transcriber(file_path)
    case TRANSCRIPTION_ENGINE
    when "gpt-4o-transcribe"
      GptTranscribe.new(file_path)
    else
      Deepgram.new(file_path)
    end
  end

  # ── Provider cost tracking ─────────────────────────────────────────────

  def track_transcription_usage(transcription, transcriber)
    case transcriber
    when Deepgram
      track_deepgram_usage(transcription, transcriber.duration)
    when GptTranscribe
      track_gpt_transcribe_usage(transcription, transcriber.total_tokens, transcriber.duration)
    end
  end

  def track_deepgram_usage(transcription, duration_seconds)
    return unless duration_seconds.present?

    ProviderUsage.create!(
      transcription: transcription,
      provider:      "deepgram",
      units:         duration_seconds.to_f,
      unit_type:     "seconds",
      cost_usd:      duration_seconds.to_f * ProviderUsage::DEEPGRAM_USD_PER_SECOND
    )
  rescue => e
    Rails.logger.warn "[TranscribeAudioJob] Failed to track Deepgram usage: #{e.message}"
    Sentry.capture_exception(e)
    record_error!(transcription, stage: "track_usage", error: e)
  end

  def track_openai_usage(transcription, token_count)
    return unless token_count.present?

    ProviderUsage.create!(
      transcription: transcription,
      provider:      "openai",
      units:         token_count.to_f,
      unit_type:     "tokens",
      cost_usd:      token_count.to_f * ProviderUsage::OPENAI_USD_PER_TOKEN
    )
  rescue => e
    Rails.logger.warn "[TranscribeAudioJob] Failed to track OpenAI usage: #{e.message}"
    Sentry.capture_exception(e)
    record_error!(transcription, stage: "track_usage", error: e)
  end

  def track_gpt_transcribe_usage(transcription, token_count, duration_seconds)
    if token_count.present?
      ProviderUsage.create!(
        transcription: transcription,
        provider:      "openai-transcribe",
        units:         token_count.to_f,
        unit_type:     "tokens",
        cost_usd:      token_count.to_f * ProviderUsage::GPT_TRANSCRIBE_USD_PER_TOKEN
      )
    elsif duration_seconds.present?
      ProviderUsage.create!(
        transcription: transcription,
        provider:      "openai-transcribe",
        units:         duration_seconds.to_f,
        unit_type:     "seconds",
        cost_usd:      duration_seconds.to_f * ProviderUsage::GPT_TRANSCRIBE_USD_PER_SECOND
      )
    end
  rescue => e
    Rails.logger.warn "[TranscribeAudioJob] Failed to track gpt-4o-transcribe usage: #{e.message}"
    Sentry.capture_exception(e)
    record_error!(transcription, stage: "track_usage", error: e)
  end

  def attached_audio(transcription)
    transcription.audio.download if transcription.audio.attached?
  rescue ActiveStorage::FileNotFoundError
    nil
  end

  def attach_audio(transcription, audio_data, media_url)
    extension = if media_url.blank?
      DEFAULT_AUDIO_EXTENSION
    else
      begin
        File.extname(URI.parse(media_url).path).presence || DEFAULT_AUDIO_EXTENSION
      rescue URI::InvalidURIError
        DEFAULT_AUDIO_EXTENSION
      end
    end

    filename = "transcription-#{transcription.id}#{extension}"
    transcription.audio.attach(io: StringIO.new(audio_data), filename: filename)
  rescue StandardError => e
    Rails.logger.warn "[TranscribeAudioJob] Failed to attach audio for transcription #{transcription.id}: #{e.class}: #{e.message}"
    Sentry.capture_exception(e)
    record_error!(transcription, stage: "attach_audio", error: e)
  end

  def record_error!(transcription, stage:, error:)
    TranscriptionError.create!(
      transcription: transcription,
      stage:         stage,
      error_class:   error.class.name,
      message:       error.message.to_s.truncate(2000),
      backtrace:     error.backtrace&.first(10)&.join("\n")
    )
  rescue => record_err
    Rails.logger.error "[TranscribeAudioJob] Failed to record TranscriptionError: #{record_err.message}"
    Sentry.capture_exception(record_err)
  end

  def fail_transcription!(transcription, message)
    transcription.update!(status: :failed, error_message: message)
  end

  # Registra o LIMIT_REACHED e decide se este áudio recusado leva o aviso.
  # Não leva quando:
  #   - outro aviso saiu há pouco (vários áudios encaminhados juntos, ou um
  #     encaminhado + um por reação);
  #   - um áudio anterior do chat direto ainda está transcrevendo: foi ele que
  #     gastou o último crédito, e o follow-up dele ("esse foi seu último áudio
  #     grátis") chega depois da transcrição, na ordem certa.
  # O lock no usuário serializa jobs simultâneos do mesmo usuário.
  def claim_limit_notice(transcription, user)
    user.with_lock do
      in_flight = user.waha_session.transcriptions.direct.processing
                      .where("transcriptions.id < ?", transcription.id)
                      .where("transcriptions.created_at > ?", 1.hour.ago)
                      .exists?
      notify = !in_flight && !user.limit_notice_recently_sent?

      UsageEvent.track(user: user, event_type: UsageEvent::LIMIT_REACHED,
                       metadata: { transcription_id: transcription.id, channel: transcription.channel,
                                   plan: user.plan, notified: notify })
      notify
    end
  end

  def send_limit_reached_notice(transcription, channel, user)
    text, buttons = Reply::PlanMessages.quota_exhausted(user)

    # No canal conectado o aviso iria para a conversa com o contato, então vai
    # pelo bot (quem não é usuário de WhatsApp já recebe o email abaixo); no
    # canal direto o próprio chat já é com o bot.
    if transcription.waha?
      user.notify(subject: "Limite de transcrições atingido", text: text) if user.provider == "phone"
    else
      begin
        buttons.any? ? channel.send_buttons(text, buttons) : channel.send_text(text)
      rescue => e
        Rails.logger.warn "[TranscribeAudioJob] Failed to send limit notice via WA: #{e.message}"
        Sentry.capture_exception(e)
      end
    end

    # Push Notification (com link pro billing)
    app_host = Rails.application.credentials.dig(:waha, :webhook_host) || Rails.application.config.action_mailer.default_url_options&.dig(:host) || "localhost:3000"
    billing_url = Rails.application.routes.url_helpers.billing_url(host: app_host)

    PushNotificationService.notify(
      user,
      title: "Limite de transcrições atingido",
      body: "Você usou todas as transcrições do plano #{user.plan.capitalize}. Renove para continuar.",
      url: billing_url
    )

    # Email (com link pro billing)
    UsageMailer.limit_reached(user).deliver_later
  end

  # Conta quantos áudios do usuário chegaram no minuto anterior a este. Só o
  # primeiro áudio recusado da rajada gera aviso, para não virar spam.
  def rate_limited?(transcription, user)
    window = (transcription.created_at - 1.minute)..transcription.created_at
    earlier = user.waha_session.transcriptions
                  .where(created_at: window)
                  .where("transcriptions.id < ?", transcription.id)
                  .count
    return false if earlier < User::TRANSCRIPTIONS_PER_MINUTE

    send_rate_limit_notice(transcription, user) if earlier == User::TRANSCRIPTIONS_PER_MINUTE
    true
  end

  def send_rate_limit_notice(transcription, user)
    text = "⏳ *Calma, muitos áudios de uma vez!*\n\n" \
           "Eu transcrevo até #{User::TRANSCRIPTIONS_PER_MINUTE} áudios por minuto. " \
           "Os que passaram desse limite não foram transcritos e não contaram no seu plano — " \
           "é só encaminhar de novo daqui a pouco."
    notify_user(transcription, user, subject: "Muitos áudios de uma vez", text: text)
  end

  # Áudio acima do limite de duração do plano. No chat direto, planos pagos
  # podem confirmar o gasto de créditos extras; nos outros casos é recusado.
  def handle_long_audio(transcription, channel, user, placeholder_message_id, duration)
    minutes     = (duration / 60.0).ceil
    max_minutes = user.max_audio_duration / 60

    if transcription.direct? && !user.free?
      ask_long_audio_confirmation(transcription, channel, user, duration, minutes)
      return
    end

    text = if user.free?
      "⏱️ *Esse áudio tem #{minutes} min.*\n\n" \
      "No plano Grátis eu transcrevo áudios de até #{max_minutes} min. " \
      "Nos planos Basic e Pro o limite é de 25 min — e áudios maiores podem ser transcritos usando créditos extras.\n\n" \
      "Para assinar, digite *menu* e toque em *📊 Meu plano e uso*."
    else
      "⏱️ *Esse áudio tem #{minutes} min.*\n\n" \
      "Direto nas conversas eu transcrevo áudios de até #{max_minutes} min. " \
      "Para áudios maiores, *encaminhe o áudio para mim* que eu transcrevo usando créditos extras do seu plano."
    end

    if transcription.waha?
      # O placeholder fica na conversa com o contato: só um aviso curto lá, e
      # a explicação vai pelo bot.
      channel.finalize(placeholder_message_id, "⏱️ _Áudio de #{minutes} min — acima do limite de #{max_minutes} min para transcrição._") if placeholder_message_id.present?
    end
    notify_user(transcription, user, subject: "Áudio muito longo", text: text, channel: channel)

    TrackUsageJob.perform_later(user_id: user.id, event_type: UsageEvent::AUDIO_TOO_LONG,
                                metadata: { transcription_id: transcription.id, duration: duration, plan: user.plan })
    fail_transcription!(transcription, "Áudio de #{minutes} min acima do limite de #{max_minutes} min do plano #{user.plan}")
  end

  def ask_long_audio_confirmation(transcription, channel, user, duration, minutes)
    credits   = Transcription.credits_for_duration(duration)
    remaining = user.transcription_credits_remaining(excluding: transcription)

    if credits > remaining
      channel.send_text("⏱️ *Esse áudio tem #{minutes} min* e custaria *#{credits} créditos* " \
                        "(1 a cada 25 min), mas você só tem #{remaining} disponíveis este mês.")
      fail_transcription!(transcription, "Créditos insuficientes para áudio de #{minutes} min (#{credits} > #{remaining})")
      return
    end

    transcription.update!(status: :awaiting_confirmation, credits: credits)
    channel.send_buttons(
      "⏱️ *Esse áudio tem #{minutes} min* — acima do limite de 25 min por áudio.\n\n" \
      "Posso transcrever usando *#{credits} créditos* do seu plano (1 a cada 25 min). " \
      "Você tem #{remaining} disponíveis este mês.",
      [ [ "long_audio_confirm:#{transcription.id}", "Transcrever" ], [ "long_audio_cancel:#{transcription.id}", "Cancelar" ] ]
    )

    TrackUsageJob.perform_later(user_id: user.id, event_type: UsageEvent::LONG_AUDIO_CONFIRMATION_REQUESTED,
                                metadata: { transcription_id: transcription.id, duration: duration, credits: credits })
  end

  # Avisos que não são a transcrição: no chat direto vão no próprio chat; no
  # conectado vão pelo bot (a conversa é com o contato).
  def notify_user(transcription, user, subject:, text:, channel: nil)
    if transcription.direct?
      (channel || build_channel(transcription)).send_text(text)
    else
      user.notify(subject: subject, text: text)
    end
  rescue => e
    Rails.logger.warn "[TranscribeAudioJob] Falha ao enviar aviso (#{subject}): #{e.message}"
    Sentry.capture_exception(e) unless Meta::Service.pair_rate_limited?(e)
  end

  def send_reaction_limit_notice(user)
    text = "⚡ *Você usou as #{User::REACTION_TRIAL_LIMIT} transcrições por reação deste mês.*\n\n" \
           "Transcrever direto nas conversas é um recurso do plano *Pro*. " \
           "Enquanto isso, é só *encaminhar o áudio para mim* que eu transcrevo aqui.\n\n" \
           "Para assinar o Pro, digite *menu* e toque em *📊 Meu plano e uso*."

    user.notify(subject: "Limite de transcrições por reação atingido", text: text)
  end
end
