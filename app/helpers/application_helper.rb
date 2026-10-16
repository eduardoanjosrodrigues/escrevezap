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

  def official_whatsapp_url
    "https://wa.me/558296801867?text=Oi!%20Gostaria%20de%20conhecer%20os%20servi%C3%A7os"
  end

  # Assinaturas são feitas pelo bot (Pix Automático do Inter).
  def whatsapp_subscribe_url(plan)
    "https://wa.me/558296801867?text=#{ERB::Util.url_encode("Quero assinar o plano #{plan.to_s.capitalize}")}"
  end
end
