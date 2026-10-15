module Waha
  # Manages WhatsApp session lifecycle via the WAHA Sessions API.
  #
  # Usage:
  #   client = Waha::Client.new(session: "default")
  #   client.sessions.create
  #   client.sessions.qr
  #   client.sessions.destroy
  class SessionsApi < Service
    # Create (and auto-start) a new session.
    # Registers a webhook for `message.ack` and `session.status` events pointing
    # to {host}/webhook/waha so the app can track delivery and auth state changes.
    #
    # POST /api/sessions
    def create(name: @session, webhook_url: nil)
      @api_request.post("/api/sessions", {
        name: name,
        start: true,
        config: {
          webhooks: [
            {
              url: webhook_url || default_webhook_url,
              events: ["message.any", "session.status", "message.reaction"],
              retries: {
                policy: "exponential",
                delaySeconds: 2,
                attempts: 10
              }
            }
          ],
          ignore: {
            groups: true,
            channels: true,
            broadcast: true
          }
        }
      })
    end

    # Request a pairing code to link a session via phone number instead of QR.
    # Must be called after the session starts (during STARTING state).
    # The user enters the returned code in WhatsApp → Linked Devices → Link with phone number.
    # Returns { "code" => "ABCD-ABCD" }
    #
    # POST /api/{session}/auth/request-code
    def request_pairing_code(phone_number:, name: @session)
      response = @api_request.post("/api/#{name}/auth/request-code", {
        phoneNumber: phone_number
      })
      JSON.parse(response)
    end

    # List all sessions.
    # Pass `all: true` to include STOPPED sessions.
    #
    # GET /api/sessions
    def list(all: false)
      @api_request.get("/api/sessions", all ? { all: true } : {})
    end

    # Get a specific session.
    #
    # GET /api/sessions/{session}
    def get(name = @session)
      JSON.parse(@api_request.get("/api/sessions/#{name}"))
    end

    # Start a session (idempotent – safe to call on an already-running session).
    #
    # POST /api/sessions/{session}/start
    def start(name = @session)
      @api_request.post("/api/sessions/#{name}/start")
    end

    # Stop a session without logging out or deleting data.
    #
    # POST /api/sessions/{session}/stop
    def stop(name = @session)
      @api_request.post("/api/sessions/#{name}/stop")
    end

    # Restart a session (stop → start).
    #
    # POST /api/sessions/{session}/restart
    def restart(name = @session)
      @api_request.post("/api/sessions/#{name}/restart")
    end

    # Log out a session (removes auth data, keeps config).
    #
    # POST /api/sessions/{session}/logout
    def logout(name = @session)
      @api_request.post("/api/sessions/#{name}/logout")
    end

    # Delete a session completely (logs out + removes config).
    #
    # DELETE /api/sessions/{session}
    def destroy(name = @session)
      @api_request.delete("/api/sessions/#{name}")
    end

    # Get the current account info for an authenticated session.
    # Returns nil if the session is not yet authenticated.
    #
    # GET /api/sessions/{session}/me
    def me(name = @session)
      JSON.parse(@api_request.get("/api/sessions/#{name}/me"))
    end

    # Get the QR code for authentication.
    # Returns base64-encoded PNG data: { "mimetype" => "image/png", "data" => "..." }
    #
    # GET /api/{session}/auth/qr
    def qr(name = @session)
      JSON.parse(@api_request.get("/api/#{name}/auth/qr"))
    end

    private

    # Builds the default webhook URL from Rails credentials or mailer defaults.
    # Configure via credentials: waha.webhook_host (e.g. "https://yourapp.com")
    def default_webhook_url
      host = Rails.application.credentials.dig(:waha, :webhook_host) ||
             begin
               opts = Rails.application.config.action_mailer.default_url_options || {}
               protocol = opts[:protocol] || "https"
               "#{protocol}://#{opts[:host]}"
             end
      "#{host}/webhook/waha"
    end
  end
end
