module ApplicationHelper
  include Pagy::Frontend

  # Formats an E.164 phone number for display.
  # Brazilian (+55): (11) 99999-9999 or (11) 9999-9999
  # Others: returned as-is
  def format_phone(number)
    digits = number.to_s.gsub(/\D/, "")
    if digits.start_with?("55") && digits.length.in?([12, 13])
      local = digits[2..]
      area  = local[0, 2]
      num   = local[2..]
      num.length == 9 ? "(#{area}) #{num[0, 5]}-#{num[5..]}" : "(#{area}) #{num[0, 4]}-#{num[4..]}"
    else
      number.to_s
    end
  end

  # Abre o bot oficial. `ref` identifica o botão clicado (ex. "home-hero") e
  # vai no fim da mensagem para o bot registrar de onde veio o contato
  # (User.acquisition_from). O JS da landing acrescenta o canal (~google,
  # ~instagram, utm) antes do clique.
  def official_whatsapp_url(ref = "site")
    "https://wa.me/558296801867?text=#{ERB::Util.url_encode("Oi! Quero testar o EscreveZap 🎙️ [#{ref}]")}"
  end

  # Assinaturas são feitas pelo bot (Pix Automático do Inter).
  def whatsapp_subscribe_url(plan)
    "https://wa.me/558296801867?text=#{ERB::Util.url_encode("Quero assinar o plano #{plan.to_s.capitalize}")}"
  end
end
