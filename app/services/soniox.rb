require "net/http"

# Transcrição assíncrona da Soniox: envia o arquivo, cria a transcrição, espera
# concluir e lê o texto. No fim apaga o arquivo e a transcrição da Soniox (não
# guardamos áudio de cliente em terceiros).
class Soniox
  include Loggable

  class Error < StandardError; end

  API_URL       = "https://api.soniox.com/v1".freeze
  MODEL         = "stt-async-v5".freeze
  POLL_INTERVAL = 0.5
  POLL_TIMEOUT  = 120 # segundos

  KEYWORDS = %w[Pix WhatsApp CNPJ CPF boleto].freeze

  attr_reader :duration

  def initialize(audio_file_path)
    @audio_file_path = audio_file_path
  end

  def speech_to_text(content_type: "audio/ogg")
    log_info "Convertendo áudio para texto com Soniox"

    file_id = transcription_id = nil

    File.open(@audio_file_path, "rb") do |file|
      file_id = request(:Post, "/files", form: [ [ "file", file, { filename: File.basename(@audio_file_path), content_type: content_type } ] ])["id"]
    end

    transcription_id = request(:Post, "/transcriptions", json: {
      model:          MODEL,
      file_id:        file_id,
      language_hints: [ "pt" ],
      context:        { terms: KEYWORDS }
    })["id"]

    status = wait_for(transcription_id)
    @duration = status["audio_duration_ms"].to_f / 1000 if status["audio_duration_ms"]

    request(:Get, "/transcriptions/#{transcription_id}/transcript")["text"].to_s.strip
  ensure
    cleanup("/transcriptions/#{transcription_id}") if transcription_id
    cleanup("/files/#{file_id}") if file_id
  end

  private

  def wait_for(transcription_id)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + POLL_TIMEOUT

    loop do
      status = request(:Get, "/transcriptions/#{transcription_id}")

      case status["status"]
      when "completed" then return status
      when "error"     then raise Error, "Soniox: #{status['error_type']} #{status['error_message']}"
      end

      raise Error, "Soniox: timeout após #{POLL_TIMEOUT}s (status #{status['status']})" if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep POLL_INTERVAL
    end
  end

  def cleanup(path)
    request(:Delete, path)
  rescue StandardError => e
    log_warning "Falha ao apagar #{path} na Soniox: #{e.message}"
  end

  def request(method, path, json: nil, form: nil)
    url = URI.parse("#{API_URL}#{path}")
    req = Net::HTTP.const_get(method).new(url)
    req["Authorization"] = "Bearer " + Rails.application.credentials.dig(:soniox, :api_key)

    if form
      req.set_form(form, "multipart/form-data")
    elsif json
      req["Content-Type"] = "application/json"
      req.body = json.to_json
    end

    response = Net::HTTP.start(url.host, url.port, use_ssl: true, open_timeout: 5, read_timeout: 60) do |http|
      http.request(req)
    end

    raise Error, "Soniox HTTP #{response.code}: #{response.body.to_s.truncate(500)}" unless response.is_a?(Net::HTTPSuccess)

    response.body.blank? ? {} : JSON.parse(response.body)
  end
end
