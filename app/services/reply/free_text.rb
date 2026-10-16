module Reply
  # Texto livre (fora de botões/listas): responde perguntas frequentes por
  # palavra-chave, repassa perguntas desconhecidas para o time e protege contra
  # outros bots que ficam respondendo o nosso menu em loop. O menu só aparece
  # quando pedido ("menu"); fora isso, lembramos que é só encaminhar o áudio.
  module FreeText
    LOOP_WINDOW    = 5.minutes
    LOOP_THRESHOLD = 10
    LOOP_SILENCE   = 6.hours
    # Mensagens curtas não reconhecidas ("oi", "ok") ganham um lembrete de
    # como usar; as mais longas costumam ser perguntas e vão para o time.
    QUESTION_MIN_LENGTH = 15

    FAQS = [
      { patterns: [/\Amenu\z/, /\bopcoes\b/, /\bmenu principal\b/], action: :show_menu },
      {
        patterns: [/outra pessoa/, /\bcontato (ve|vai ver|consegue ver)/, /(pessoa|ele|ela) (vai )?(ve|ver|ler|le)\b/, /aparece (pra|para) (pessoa|ele|ela|o contato)/],
        answer: "Depende de como você usa:\n\n" \
                "🎙️ *Encaminhando o áudio para mim:* só você vê a transcrição, ela chega aqui na nossa conversa.\n\n" \
                "⚡ *Transcrever no chat (Pro):* a transcrição é enviada como resposta ao áudio na própria conversa, então o contato também vê."
      },
      {
        patterns: [/automatic/, /sem (precisar )?(reagir|encaminhar)/],
        answer: "A transcrição acontece quando você pede: *encaminhando o áudio para mim* ou, no recurso Pro *Transcrever no chat*, reagindo ao áudio com qualquer emoji. " \
                "Assim você escolhe quais áudios transcrever e não gasta sua cota à toa."
      },
      {
        patterns: [/cancel/],
        answer: "Para cancelar, digite *menu* e toque em *📊 Meu plano e uso* → *Cancelar Assinatura*. " \
                "Você também pode cancelar o Pix Automático direto no app do seu banco."
      },
      { patterns: [/quanto custa/, /\bpreco/, /\bvalor/, /\bplanos?\b/, /\bassinar\b/, /\bassinatura\b/], action: :show_plans },
      { patterns: [/como (funciona|usa|uso|faz|faco|transcrev)/, /\bajuda\b/, /nao (sei|entendi)/, /tutorial/], action: :show_how_it_works }
    ].freeze

    private

    def handle_free_text(message)
      text = normalize_free_text(message)

      # Reações e mensagens que o parser da Meta não entende não pedem resposta.
      return if text.start_with?("unsupported message type")
      return if bot_loop_silenced?

      faq = FAQS.find { |f| f[:patterns].any? { |p| p.match?(text) } }

      if faq
        reset_unrecognized_count
        faq[:answer] ? answer_faq(faq[:answer]) : send(faq[:action])
      elsif !welcomed?
        reply_unrecognized { start_onboarding }
      elsif text.length < QUESTION_MIN_LENGTH
        reply_unrecognized { send_message(message: "Eu transcrevo áudios 🙂 Me encaminha um! Se precisar de algo, digite *menu*.") }
      else
        reply_unrecognized { forward_question_to_team(message) }
      end
    end

    def answer_faq(answer)
      send_message(message: answer)
    end

    def forward_question_to_team(message)
      send_message(message: "Recebi sua mensagem! 🙌 Vou passar para o nosso time, que te responde pelo WhatsApp do suporte em breve.")

      text = "Pergunta de #{@display_name.presence || 'usuário'} (+#{@phone}, user #{@user.id}) no bot do EscreveZap:\n\n#{message}"
      User.where(admin: true).find_each { |admin| admin.notify(subject: "Pergunta no bot do EscreveZap", text: text) }

      Rails.logger.info(event: "bot_question_forwarded", user_id: @user.id)
    end

    # Outro bot respondendo o nosso menu manda mensagens não reconhecidas sem
    # parar: não repetimos a resposta em seguida e, passado o limite, ficamos
    # em silêncio com aquele número por um tempo.
    def reply_unrecognized
      now = Time.current
      recent = Array(@current_conversation_state["unrecognized_at"])
                 .map { |t| Time.zone.parse(t.to_s) rescue nil }
                 .compact
                 .select { |t| t > now - LOOP_WINDOW }
      recent << now
      @current_conversation_state["unrecognized_at"] = recent.map(&:iso8601)

      if recent.size > LOOP_THRESHOLD
        @current_conversation_state["silenced_until"] = (now + LOOP_SILENCE).iso8601
        Rails.logger.warn(event: "bot_loop_silenced", user_id: @user.id, messages: recent.size)
        Sentry.capture_message("Bot loop detectado: silenciando user #{@user.id} por #{LOOP_SILENCE.inspect}", level: :warning)
        return
      end

      last_reply = Time.zone.parse(@current_conversation_state["last_unrecognized_reply_at"].to_s) rescue nil
      return if last_reply && last_reply > now - 1.minute && recent.size > 2

      @current_conversation_state["last_unrecognized_reply_at"] = now.iso8601
      yield
    end

    def reset_unrecognized_count
      @current_conversation_state.delete("unrecognized_at")
    end

    def bot_loop_silenced?
      until_at = Time.zone.parse(@current_conversation_state["silenced_until"].to_s) rescue nil
      until_at.present? && until_at > Time.current
    end

    # Sem o código de origem do site ("[home-planos-pro]"), que não é parte da
    # pergunta e casaria com as palavras-chave do FAQ.
    def normalize_free_text(message)
      I18n.transliterate(message.to_s.gsub(User::ACQUISITION_CODE, "")).downcase.squish
    end
  end
end
