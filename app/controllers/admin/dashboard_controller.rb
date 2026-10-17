module Admin
  class DashboardController < Admin::BaseController
    BASIC_PRICE = Subscription::PRICES["basic"]
    PRO_PRICE   = Subscription::PRICES["pro"]

    def index
      today       = Date.current
      month_start = today.beginning_of_month

      # ── Users ───────────────────────────────────────────────────────────
      @total_users          = User.count
      @new_users_this_month = User.where("created_at >= ?", month_start).count
      @new_users_last_month = User.where(created_at: 1.month.ago.beginning_of_month...month_start).count
      @mau                  = UsageEvent.where(occurred_at: 30.days.ago..)
                                        .select(:user_id).distinct.count

      # ── Plans ───────────────────────────────────────────────────────────
      plan_counts  = User.group(:plan).count
      @free_count  = plan_counts["free"].to_i
      @basic_count = plan_counts["basic"].to_i
      @pro_count   = plan_counts["pro"].to_i
      @paid_count  = @basic_count + @pro_count

      # ── MRR ─────────────────────────────────────────────────────────────
      @mrr = (@basic_count * BASIC_PRICE) + (@pro_count * PRO_PRICE)

      # ── Conversion rate ─────────────────────────────────────────────────
      @conversion_rate = @total_users > 0 ? (@paid_count.to_f / @total_users * 100).round(1) : 0.0

      # ── Subscriptions ───────────────────────────────────────────────────
      @active_subscriptions = Subscription.where(status: %w[active trialing]).count
      @cancelled_this_month = Subscription.where(status: :cancelled)
                                          .where("cancelled_at >= ?", month_start).count

      # ── Transcriptions ──────────────────────────────────────────────────
      @transcriptions_today      = Transcription.where("created_at >= ?", today).count
      @transcriptions_this_month = Transcription.where("created_at >= ?", month_start).count
      @failed_transcriptions     = Transcription.failed.where("created_at >= ?", month_start).count

      # ── Job errors ──────────────────────────────────────────────────────
      @job_errors_today      = TranscriptionError.where("created_at >= ?", today).count
      @job_errors_this_month = TranscriptionError.this_month.count
      @job_errors_by_stage   = TranscriptionError.this_month.group(:stage).count

      # ── Daily transcriptions (line chart — last 30 days) ────────────────
      raw = UsageEvent
        .where(event_type: UsageEvent::TRANSCRIPTION_COMPLETED)
        .where("occurred_at >= ?", 30.days.ago)
        .group("DATE(occurred_at)")
        .count
        .transform_keys { |d| d.to_s }

      dates = 29.downto(0).map { |n| (today - n.days).to_s }
      @chart_labels = dates.to_json
      @chart_data   = dates.map { |d| raw[d].to_i }.to_json

      # ── New users per day (bar chart — last 30 days) ─────────────────────
      raw_users = User
        .where("created_at >= ?", 30.days.ago)
        .group("DATE(created_at)")
        .count
        .transform_keys { |d| d.to_s }

      @users_chart_data = dates.map { |d| raw_users[d].to_i }.to_json

      # ── Provider costs ──────────────────────────────────────────────────
      @deepgram_cost_this_month = ProviderUsage.deepgram.this_month.total_cost_usd
      @soniox_cost_this_month   = ProviderUsage.soniox.this_month.total_cost_usd
      @openai_cost_this_month   = ProviderUsage.openai.this_month.total_cost_usd
      @whatsapp_cost_this_month = WhatsappCost.summary(WhatsappCost.messages(since: month_start))[:estimated_usd]
      @total_cost_this_month    = @deepgram_cost_this_month + @soniox_cost_this_month + @openai_cost_this_month + @whatsapp_cost_this_month

      # ── Teste A/B de STT (últimos 30 dias, só transcrições com motor gravado) ──
      @stt_rollout_percent = TranscriptionEngine.rollout_percent
      @stt_engines = stt_engine_stats(30.days.ago)

      # ── Deepgram prepaid credit ─────────────────────────────────────────
      @deepgram_balance     = Deepgram.balance_usd
      @deepgram_balance_low = @deepgram_balance && @deepgram_balance < Deepgram::LOW_BALANCE_USD

      # ── External events ──────────────────────────────────────────────────
      @failed_external_events  = ExternalEvent.where(status: :failed)
                                              .where("created_at >= ?", month_start).count
      @pending_external_events = ExternalEvent.where(status: :pending).count
    end

    private

    # Uma linha por motor: volume, falhas, transcrições vazias, minutos de
    # áudio, custo e tempo mediano do pedido até a transcrição concluída.
    def stt_engine_stats(since)
      scope = Transcription.where(created_at: since..).where.not(engine: nil)
      costs = ProviderUsage.where(provider: %w[deepgram soniox openai-transcribe])
                           .joins(:transcription).merge(scope)
                           .group("transcriptions.engine").sum(:cost_usd)

      scope.joins(monitored_contact: :waha_session).group("transcriptions.engine").pluck(
        Arel.sql("transcriptions.engine"),
        Arel.sql("COUNT(*)"),
        Arel.sql("COUNT(DISTINCT waha_sessions.user_id)"),
        Arel.sql("COUNT(*) FILTER (WHERE transcriptions.status = 'failed')"),
        Arel.sql("COUNT(*) FILTER (WHERE transcriptions.error_message LIKE '%retornou transcrição vazia')"),
        Arel.sql("COALESCE(SUM(transcriptions.audio_duration), 0) / 60.0"),
        Arel.sql("PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM transcriptions.updated_at - transcriptions.created_at)) FILTER (WHERE transcriptions.status = 'completed')")
      ).map do |engine, total, users, failed, empty, minutes, median_secs|
        cost = costs[engine].to_f
        { engine: engine, total: total, users: users, failed: failed, empty: empty,
          minutes: minutes.to_f, cost: cost, cost_per_min: minutes.to_f > 0 ? cost / minutes.to_f : 0,
          median_secs: median_secs&.round(1) }
      end.sort_by { |row| -row[:total] }
    end
  end
end
