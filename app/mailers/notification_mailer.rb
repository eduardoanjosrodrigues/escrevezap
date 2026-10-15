# Versão por email das notificações que usuários de telefone recebem no
# WhatsApp (ver User#notify). O texto vem no formato do WhatsApp.
class NotificationMailer < ApplicationMailer
  helper NotificationMailerHelper

  def notice(user, subject, text)
    @user = user
    @text = text
    mail(to: @user.email, subject: subject)
  end
end
