module NotificationMailerHelper
  # Converte a formatação do WhatsApp (*negrito*, _itálico_, quebras de linha) para HTML.
  def whatsapp_text_to_html(text)
    html = ERB::Util.html_escape(text.to_s)
                    .gsub(/\*([^*\n]+)\*/, '<strong>\1</strong>')
                    .gsub(/(?<![\w])_([^_\n]+)_(?![\w])/, '<em>\1</em>')
    simple_format(html, {}, sanitize: false)
  end
end
