require 'net/http'

class Deepgram
  include Loggable

  attr_reader :duration

  def initialize(audio_file_path)
    @audio_file_path = audio_file_path
  end

  DEFAULT_PARAMS = {
    model:            "nova-3",
    language:         "pt-BR",
    smart_format:     true,
    punctuate:        true,
    paragraphs:       true,
    diarize:          false,
    filler_words:     true,
    utterances:       true,
    numerals:         true,
    profanity_filter: false,
    detect_language:  false
  }.freeze

  KEYWORDS = %w[Pix WhatsApp CNPJ CPF boleto].freeze

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
