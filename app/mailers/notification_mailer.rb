# Versão por email das notificações que usuários de telefone recebem no
# WhatsApp (ver User#notify). O texto vem no formato do WhatsApp.
class NotificationMailer < ApplicationMailer
  helper NotificationMailerHelper

  # cta: { label:, url: } — sem cta, o botão leva para a assinatura.
  def notice(user, subject, text, cta = nil)
    @user = user
    @text = text
    @cta  = cta
    mail(to: @user.email, subject: subject)
  end
end
