# Lê a duração de um áudio Ogg (Opus ou Vorbis) direto dos bytes, sem ffmpeg.
# Notas de voz do WhatsApp são sempre Ogg/Opus, então isso permite checar o
# limite de duração do plano ANTES de pagar o STT.
#
# A duração é o granule position da última página Ogg dividido pela taxa de
# amostragem (48 kHz fixos no Opus, menos o pre-skip do cabeçalho OpusHead).
# Retorna nil para formatos que não são Ogg (mp3, m4a...) ou arquivos
# corrompidos — quem chama deve deixar esses passarem.
class OggDuration
  OPUS_GRANULE_RATE = 48_000
  PAGE_MAGIC        = "OggS".b

  def self.seconds(data)
    new(data).seconds
  end

  def initialize(data)
    @data = data.to_s.b
  end

  def seconds
    return nil unless @data.start_with?(PAGE_MAGIC)

    granule = last_granule_position
    return nil if granule.nil?

    if (head = @data.index("OpusHead".b))
      pre_skip = @data.byteslice(head + 10, 2)&.unpack1("v").to_i
      (granule - pre_skip).clamp(0, nil).to_f / OPUS_GRANULE_RATE
    elsif (vorbis = @data.index("\x01vorbis".b))
      rate = @data.byteslice(vorbis + 12, 4)&.unpack1("V").to_i
      rate.positive? ? granule.to_f / rate : nil
    end
  end

  private

  # Procura de trás pra frente a última página válida com granule definido.
  # "OggS" pode aparecer por acaso dentro do payload, então confere a versão
  # do formato (byte 4 == 0); granule -1 indica página sem fim de pacote.
  def last_granule_position
    pos = @data.bytesize

    while (pos = @data.rindex(PAGE_MAGIC, pos - 1))
      header = @data.byteslice(pos, 14)
      if header&.bytesize == 14 && header.getbyte(4).zero?
        granule = header.byteslice(6, 8).unpack1("q<")
        return granule if granule >= 0
      end
      return nil if pos.zero?
    end

    nil
  end
end
