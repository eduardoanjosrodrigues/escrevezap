module Reply
  # Textos sobre planos, saldo e limite, usados pelo bot (Reply), pelo
  # TranscribeAudioJob (limite atingido) e pelo TranscriptionFollowUpJob
  # (avisos depois da transcrição). Botões: [[id, título ≤ 20 caracteres]].
  module PlanMessages
    module_function

    def brl(value)
      format("R$ %.2f", value).tr(".", ",")
    end

    # Grátis e pacote: Basic, pacote avulso e Pro (o WhatsApp aceita até 3 botões)
    def upgrade_buttons
      [
        [ "upgrade_basic", "Basic · #{brl(Subscription::PRICES["basic"])}" ],
        [ "buy_pack",      "#{AudioPack::CREDITS} áudios · #{brl(AudioPack::PRICE)}" ],
        [ "upgrade_pro",   "Pro · #{brl(Subscription::PRICES["pro"])}" ]
      ]
    end

    def plans_overview
      basic = Subscription::PRICES["basic"]
      pro   = Subscription::PRICES["pro"]
      limits = User::TRANSCRIPTION_LIMITS

      <<~MSG.strip
        • *Basic* · #{brl(basic)}/mês: #{limits["basic"]} transcrições por mês
        • *Pacote avulso* · #{brl(AudioPack::PRICE)}: #{AudioPack::CREDITS} transcrições com IA, pagamento único sem assinatura
        • *Pro* · #{brl(pro)}/mês: #{number(limits["pro"])} transcrições por mês, resumo com IA e *Transcrever no chat*
      MSG
    end

    # "Você ainda tem 4 áudios grátis para testar." (só faz sentido no Grátis)
    def free_remaining_line(user, remaining = user.transcription_credits_remaining)
      return nil unless user.lifetime_quota?
      return "Esse foi seu último áudio grátis." if remaining.zero?

      remaining == 1 ? "Você ainda tem *1 áudio grátis* para testar." : "Você ainda tem *#{remaining} áudios grátis* para testar."
    end

    # Saldo baixo (antes de acabar)
    def quota_low(user, remaining)
      if user.on_pack?
        "Restam *#{remaining} transcrições* do seu pacote."
      elsif user.lifetime_quota?
        "Restam *#{remaining} áudios grátis* para você testar. Depois disso, o Basic sai por " \
          "#{brl(Subscription::PRICES["basic"])}/mês com #{User::TRANSCRIPTION_LIMITS["basic"]} transcrições."
      else
        "Restam *#{remaining} transcrições* do seu plano #{user.plan.capitalize} este mês. " \
          "Elas renovam em #{renewal_date(user).strftime("%d/%m")}."
      end
    end

    # [texto, botões] quando o saldo acaba (na última transcrição ou ao tentar
    # passar do limite).
    def quota_exhausted(user, just_used_last: false)
      if user.on_pack?
        intro = just_used_last ? "Essa foi a última transcrição do seu pacote. 🙌" : "Você já usou as #{user.transcription_limit} transcrições do seu pacote. 🙌"
        [ "#{intro}\n\nPara continuar transcrevendo, escolha uma opção:\n\n#{plans_overview}", upgrade_buttons ]
      elsif user.lifetime_quota?
        intro = just_used_last ? "Esse foi seu último áudio grátis. 🙌" : "Você já usou seus #{user.transcription_limit} áudios grátis. 🙌"
        [ "#{intro}\n\nPara continuar transcrevendo, escolha um plano:\n\n#{plans_overview}", upgrade_buttons ]
      elsif user.basic?
        text = "Você usou as #{user.transcription_limit} transcrições do Basic este mês. Elas renovam em " \
               "#{renewal_date(user).strftime("%d/%m")}.\n\nPrecisa de mais agora? O *Pro* tem " \
               "#{number(User::TRANSCRIPTION_LIMITS["pro"])} por mês, por #{brl(Subscription::PRICES["pro"])}."
        [ text, [ upgrade_buttons.last ] ]
      else
        [ "Você usou as #{number(user.transcription_limit)} transcrições do seu plano este mês. " \
          "Elas renovam em #{renewal_date(user).strftime("%d/%m")}.", [] ]
      end
    end

    def pro_upsell
      "Sabia que dá pra transcrever sem encaminhar? ⚡\n\n" \
        "No *Pro*, você conecta seu WhatsApp e é só reagir ao áudio com 👍: a transcrição aparece na própria conversa. " \
        "No Basic dá pra testar até #{User::REACTION_TRIAL_LIMIT} vezes por mês."
    end

    def renewal_date(user)
      sub = user.subscription
      sub&.active_or_trialing? && sub.current_period_end.present? ? sub.current_period_end : Time.current.next_month.beginning_of_month
    end

    def number(value)
      value.to_s.reverse.scan(/\d{1,3}/).join(".").reverse
    end
  end
end
