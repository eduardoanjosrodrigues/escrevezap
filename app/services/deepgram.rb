require 'net/http'

class Deepgram
  include Loggable

  class Error < StandardError; end

  attr_reader :duration

  def initialize(audio_file_path)
    @audio_file_path = audio_file_path
  end

  DEFAULT_PARAMS = {
    model:            "nova-3",
    language:         "pt-BR",
    # smart_format troca "um" por "1" ("1 beijo", "1 banhozinho") mesmo com
    # numerals: false. Sem ele os números saem por extenso ("duzentos").
    smart_format:     false,
    punctuate:        true,
    paragraphs:       true,
    diarize:          false,
    filler_words:     true,
    utterances:       true,
    numerals:         false,
    profanity_filter: false,
    detect_language:  false
  }.freeze

  KEYWORDS = %w[Pix WhatsApp CNPJ CPF boleto].freeze

  LOW_BALANCE_USD = 20

  # Remaining prepaid credit (USD) summed across all projects of the API key.
  # Cached for 10 minutes; returns nil when the API is unreachable.
  def self.balance_usd
    Rails.cache.fetch("deepgram/balance_usd", expires_in: 10.minutes, skip_nil: true) do
      projects = api_get("/projects").fetch("projects", [])
      projects.sum do |project|
        api_get("/projects/#{project['project_id']}/balances")
          .fetch("balances", [])
          .sum { |b| b["amount"].to_f }
      end
    end
  rescue StandardError => e
    log_error "Falha ao consultar saldo da Deepgram: #{e.message}"
    nil
  end

  def self.api_get(path)
    url = URI.parse("https://api.deepgram.com/v1#{path}")
    request = Net::HTTP::Get.new(url)
    request["Authorization"] = 'Token ' + Rails.application.credentials.dig(:deepgram, :api_key)

    response = Net::HTTP.start(url.host, url.port, use_ssl: true, open_timeout: 3, read_timeout: 5) do |http|
      http.request(request)
    end

    raise Error, "Deepgram HTTP #{response.code}: #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  end
  private_class_method :api_get

  def speech_to_text(twilio = false, content_type: "audio/ogg")
    log_info "Convertendo áudio para texto com Deepgram"

    url = URI.parse("https://api.deepgram.com/v1/listen?#{build_query}")

    audio_data = File.binread(@audio_file_path)

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(url)

    request["Authorization"] = 'Token ' + Rails.application.credentials.dig(:deepgram, :api_key)
    request["Content-Type"] = content_type

    request.body = audio_data

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise Error, "Deepgram HTTP #{response.code}: #{response.body.to_s.truncate(500)}"
    end

    parsed_response = JSON.parse(response.body)

    @duration = parsed_response['metadata']['duration']

    parsed_response['results']['channels'][0]['alternatives'][0]['transcript']
  end

  private

  def build_query
    pairs = DEFAULT_PARAMS.map { |k, v| "#{k}=#{v}" }
    pairs += KEYWORDS.map { |kw| "keyterm=#{URI.encode_www_form_component(kw)}" }
    pairs.join("&")
  end
end
