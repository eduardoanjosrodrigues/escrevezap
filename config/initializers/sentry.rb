Sentry.init do |config|
  config.dsn = "https://94e093f826a04988893f8f33eb6fd9a4@escrevezap.bugsink.com/1"
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # Allow all environments to report to ensure we catch manual reporting during testing/dev if needed,
  # but Sentry defaults to only reporting when DSN is present.
  # We can also restrict environments if desired:
  config.enabled_environments = %w[production]

  # A Meta inclui um fbtrace_id único em cada erro, o que faz o mesmo erro virar
  # uma issue nova a cada ocorrência no Bugsink. Agrupa pela mensagem sem ele.
  config.before_send = lambda do |event, hint|
    exception = hint[:exception]
    if exception.is_a?(ApiRequest::ApiError) && exception.message.include?("graph.facebook.com")
      event.fingerprint = [ "meta-api", exception.class.name, exception.message.gsub(/"fbtrace_id":"[^"]*"/, "") ]
    end
    event
  end
end
