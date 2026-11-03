class FormattingStyleController < ApplicationController
  layout "authenticated"
  before_action :authenticate_user!
  before_action :require_pro!

  def show; end

  def update
    if current_user.update(formatting_style: params[:formatting_style])
      redirect_to formatting_style_path, notice: "Modelo de formatação atualizado."
    else
      redirect_to formatting_style_path, alert: "Não foi possível salvar a preferência."
    end
  end

  private

  def require_pro!
    unless current_user.pro_features?
      redirect_to profile_path, alert: "O modelo de formatação está disponível apenas no plano Pro."
    end
  end
end
