require "fileutils"

module Inter
  class Client
    include Loggable

    BASE_URL = "https://cdpj.partners.bancointer.com.br"
    CLIENT_ID = Rails.application.credentials.dig(:inter, :client_id)
    CLIENT_SECRET = Rails.application.credentials.dig(:inter, :client_secret)
    TOKEN_CACHE_DIR = Rails.root.join("tmp", "inter_tokens")

    class InterError < StandardError; end

    def initialize(scope)
      @scope = scope
      @token = nil
      @token_expires_at = nil
      ensure_cache_directory
      load_cached_token
    end

    # Métodos públicos para fazer requisições autenticadas
    def get(path, params = {})
      make_authenticated_request(:get, path, params: params)
    end

    def post(path, body = {})
      make_authenticated_request(:post, path, body: body)
    end

    def put(path, body = {})
      make_authenticated_request(:put, path, body: body)
    end

    def patch(path, body = {})
      make_authenticated_request(:patch, path, body: body)
    end

    def delete(path)
      make_authenticated_request(:delete, path)
    end

    # Método de conveniência para criar clientes para diferentes escopos
    def self.for_webhook_read
      new("webhook.read")
    end

    def self.for_webhook_write
      new("webhook.write")
    end

    def self.for_pix_read
      new("pix.read")
    end

    def self.for_cob_write
      new("cob.write")
    end

    def self.for_extrato_read
      new("extrato.read")
    end

    def self.for_rec_read
      new("payloadlocationrec.read rec.read")
    end

    def self.for_rec_write
      new("payloadlocationrec.write rec.write")
    end

    def self.for_cobr_read
      new("cobr.read")
    end

    def self.for_cobr_write
      new("cobr.write")
    end

    private

    def make_authenticated_request(method, path, params: {}, body: {})
      ensure_valid_token

      headers = {
        "Authorization" => "Bearer #{@token}",
        "Content-Type" => "Application/json"
      }

      make_ssl_request(method, path, body, headers, params)
    end

    def ensure_valid_token
      if token_expired?
        log_info "Token expirado ou inexistente. Renovando token para scope: #{@scope}"
        refresh_token
      end
    end

    def token_expired?
      @token.nil? || (@token_expires_at && Time.current >= @token_expires_at)
    end

    def refresh_token
      log_info "Solicitando token OAuth para scope: #{@scope}"

      begin
        response = make_token_request
        extract_and_store_token(response)
        save_token_to_cache

        log_info "Token OAuth obtido com sucesso e salvo em cache"
        log_debug "Token: #{@token[0..19]}..." if @token
      rescue => e
        log_error "Erro ao obter token OAuth: #{e.message}"
        raise InterError, "Falha ao obter token: #{e.message}"
      end
    end

    def make_token_request
      require "net/http"
      require "uri"
      require "openssl"

      uri = URI("#{BASE_URL}/oauth/v2/token")

      request_body = "client_id=#{CLIENT_ID}&client_secret=#{CLIENT_SECRET}&scope=#{@scope}&grant_type=client_credentials"

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true

      # Configurar certificados
      cert_path = Rails.root.join("files", "certificates", "certificado.crt")
      key_path = Rails.root.join("files", "certificates", "api_key.key")

      if File.exist?(cert_path) && File.exist?(key_path)
        http.cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
        http.key = OpenSSL::PKey::RSA.new(File.read(key_path))
      else
        log_error "Certificados não encontrados: #{cert_path} ou #{key_path}"
        raise InterError, "Certificados SSL não encontrados"
      end

      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/x-www-form-urlencoded"
      request.body = request_body

      response = http.request(request)

      log_info "Status da requisição OAuth: #{response.code}"

      unless response.is_a?(Net::HTTPSuccess)
        error_msg = "Erro na requisição OAuth: #{response.code} - #{response.body}"
        log_error error_msg
        raise InterError, error_msg
      end

      response
    end

    def extract_and_store_token(response)
      parsed_response = JSON.parse(response.body)
      @token = parsed_response["access_token"]
      expires_in = parsed_response["expires_in"] # segundos até expirar

      unless @token
        log_error "Token não encontrado na resposta: #{response.body}"
        raise InterError, "Token não encontrado na resposta da API"
      end

      # Definir expiração com margem de segurança (renovar 5 minutos antes)
      if expires_in
        @token_expires_at = Time.current + expires_in.seconds - 5.minutes
      else
        # Se não informar expiração, assumir 1 hora com margem
        @token_expires_at = Time.current + 55.minutes
      end

      log_debug "Token expira em: #{@token_expires_at}"
    rescue JSON::ParserError => e
      log_error "Erro ao decodificar resposta JSON: #{e.message}"
      raise InterError, "Resposta inválida da API"
    end

    def ensure_cache_directory
      FileUtils.mkdir_p(TOKEN_CACHE_DIR) unless Dir.exist?(TOKEN_CACHE_DIR)
    end

    def token_cache_file
      @token_cache_file ||= TOKEN_CACHE_DIR.join("#{@scope.gsub('.', '_')}_token.json")
    end

    def load_cached_token
      return unless File.exist?(token_cache_file)

      begin
        cached_data = JSON.parse(File.read(token_cache_file))
        @token = cached_data["access_token"]
        @token_expires_at = Time.parse(cached_data["expires_at"]) if cached_data["expires_at"]

        if token_expired?
          log_info "Token em cache expirado para scope: #{@scope}"
          delete_cached_token
        else
          log_info "Token carregado do cache para scope: #{@scope} - expira em #{@token_expires_at}"
        end
      rescue JSON::ParserError, StandardError => e
        log_error "Erro ao carregar token do cache: #{e.message}"
        delete_cached_token
      end
    end

    def save_token_to_cache
      return unless @token && @token_expires_at

      token_data = {
        "access_token" => @token,
        "expires_at" => @token_expires_at.iso8601,
        "scope" => @scope,
        "created_at" => Time.current.iso8601
      }

      File.write(token_cache_file, token_data.to_json)
      log_info "Token salvo em cache: #{token_cache_file}"
    end

    def delete_cached_token
      if File.exist?(token_cache_file)
        File.delete(token_cache_file)
        log_info "Token em cache removido: #{token_cache_file}"
      end
      @token = nil
      @token_expires_at = nil
    end

    def make_ssl_request(method, path, body = {}, headers = {}, params = {})
      require "net/http"
      require "uri"
      require "openssl"
      require "json"

      uri = URI("#{BASE_URL}#{path}")

      # Adicionar parâmetros de query se for GET
      if method == :get && params.any?
        uri.query = URI.encode_www_form(params)
      end

      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true

      # Configurar certificados
      cert_path = Rails.root.join("files", "certificates", "certificado.crt")
      key_path = Rails.root.join("files", "certificates", "api_key.key")

      if File.exist?(cert_path) && File.exist?(key_path)
        http.cert = OpenSSL::X509::Certificate.new(File.read(cert_path))
        http.key = OpenSSL::PKey::RSA.new(File.read(key_path))
      else
        log_error "Certificados não encontrados: #{cert_path} ou #{key_path}"
        raise InterError, "Certificados SSL não encontrados"
      end

      # Criar requisição baseada no método
      request = case method
      when :get
                  Net::HTTP::Get.new(uri)
      when :post
                  Net::HTTP::Post.new(uri)
      when :put
                  Net::HTTP::Put.new(uri)
      when :patch
                  Net::HTTP::Patch.new(uri)
      when :delete
                  Net::HTTP::Delete.new(uri)
      else
                  raise InterError, "Método HTTP não suportado: #{method}"
      end

      # Definir headers
      headers.each do |key, value|
        request[key] = value
      end

      # Definir body para métodos que suportam
      if [ :post, :put, :patch ].include?(method) && !body.empty?
        request.body = body.to_json
      end

      log_info "#{method.upcase} #{uri}"
      log_debug "Headers: #{headers}" if Rails.env.development?
      log_debug "Body: #{body.to_json}" if [ :post, :put, :patch ].include?(method) && body.any? && Rails.env.development?

      response = http.request(request)

      log_info "Status da resposta: #{response.code}"

      unless response.is_a?(Net::HTTPSuccess)
        resp_body = response.body.to_s.dup.force_encoding("UTF-8")
        error_msg = "Erro na requisição: #{response.code} - #{resp_body}"
        log_error error_msg
        raise InterError, error_msg
      end

      # Check if the response is HTTPNoContent
      return {} if response.is_a?(Net::HTTPNoContent)

      # Parse JSON response
      begin
        JSON.parse(response.body)
      rescue JSON::ParserError => e
        log_error "Erro ao decodificar resposta JSON: #{e.message}"
        log_error "Response body: #{response.body}"
        raise InterError, "Resposta inválida da API"
      end
    end
  end
end
