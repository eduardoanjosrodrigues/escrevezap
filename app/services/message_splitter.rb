# Splits long texts into WhatsApp-sized chunks. The Cloud API rejects text
# bodies over 4096 chars, so long transcriptions must go out as multiple
# messages. Breaks on paragraphs first, then sentences, then words, and only
# hard-cuts as a last resort.
class MessageSplitter
  MAX_LENGTH = 4096
  # Reserved for the " _(1/3)_" part marker appended to each chunk.
  MARKER_RESERVE = 16

  def self.split(text, max_length: MAX_LENGTH)
    new(text, max_length: max_length).split
  end

  def initialize(text, max_length: MAX_LENGTH)
    @text       = text.to_s
    @max_length = max_length
  end

  def split
    return [ @text ] if @text.length <= @max_length

    chunks = pack(@text, @max_length - MARKER_RESERVE)
    chunks.each_with_index.map { |chunk, i| "#{chunk}\n\n_(#{i + 1}/#{chunks.size})_" }
  end

  private

  SEPARATORS = [ /\n{2,}/, /(?<=[.!?…])\s+/, /\s+/ ].freeze

  # Greedily packs pieces into chunks of at most `limit` chars, recursing to a
  # finer separator whenever a single piece is still too long.
  def pack(text, limit, level = 0)
    return [ text ] if text.length <= limit
    return text.scan(/.{1,#{limit}}/m) if level >= SEPARATORS.size

    separator = SEPARATORS[level]
    joiner    = level.zero? ? "\n\n" : " "

    pieces = text.split(separator).reject(&:blank?).flat_map do |piece|
      piece.length > limit ? pack(piece, limit, level + 1) : [ piece ]
    end

    pieces.each_with_object([]) do |piece, chunks|
      if chunks.any? && chunks.last.length + joiner.length + piece.length <= limit
        chunks.last << joiner << piece
      else
        chunks << +piece
      end
    end
  end
end
