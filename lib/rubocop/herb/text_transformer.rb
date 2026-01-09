# frozen_string_literal: true

module RuboCop
  module Herb
    # Class for transforming HTML text content to Ruby code while preserving byte length.
    #
    # Transformation rules:
    #   Text content: "string"     → '"tr"; '      (6 bytes)
    #   Multibyte:    "日本語hello" → '"  本語he"; ' (14 bytes, padding preserves byte length)
    #
    # The first character is replaced with a quote (+ padding for multibyte).
    # The last 3 characters are replaced with '"; ' (+ padding for multibyte).
    # Text with 4 or fewer characters is not transformed.
    class TextTransformer
      # @rbs @source_bytes: Array[Integer]
      # @rbs @encoding: Encoding

      LF = 10 #: Integer

      attr_reader :config #: RuboCop::Config?
      attr_reader :source_bytes #: Array[Integer]
      attr_reader :encoding #: Encoding

      # @rbs source_bytes: Array[Integer]
      # @rbs encoding: Encoding
      # @rbs config: RuboCop::Config?
      def initialize(source_bytes, encoding:, config:) #: void
        @source_bytes = source_bytes
        @encoding = encoding
        @config = config
      end

      # @rbs text: String
      # @rbs location: ::Herb::Location
      def transform(text, location:) #: Result?
        return nil if text.length <= 4
        return nil if text.strip.empty?

        position = calculate_byte_position(location)
        content = transform_content(text)
        build_result(content, position, location)
      end

      private

      # @rbs text: String
      def transform_content(text) #: String
        first_char = text[0] || ""
        last_three = text[-3..] || ""
        middle = text[1...-3] || ""

        opening = convert_to_opening_quote(first_char)
        closing = convert_to_closing(last_three)

        "#{opening}#{middle}#{closing}"
      end

      # Converts the first character to a quote with padding to preserve byte length.
      # @rbs char: String
      def convert_to_opening_quote(char) #: String
        padding = " " * [char.bytesize - 1, 0].max
        preferred_quote + padding
      end

      # Converts the last 3 characters to '"; ' with padding to preserve byte length.
      # @rbs chars: String
      def convert_to_closing(chars) #: String
        # '"; ' is 3 bytes, pad if original chars were more
        suffix = "#{preferred_quote}; "
        padding = " " * [chars.bytesize - suffix.bytesize, 0].max
        padding + suffix
      end

      def preferred_quote #: String
        return '"' unless config

        style = config.for_cop("Style/StringLiterals")["EnforcedStyle"]
        style == "single_quotes" ? "'" : '"'
      end

      # @rbs location: ::Herb::Location
      def calculate_byte_position(location) #: Integer
        line = location.start.line # 1-based
        column = location.start.column # 0-based, character position

        # Find byte offset of line start
        line_start = 0
        current_line = 1
        source_bytes.each_with_index do |byte, index|
          break if current_line == line

          if byte == LF
            current_line += 1
            line_start = index + 1
          end
        end

        # Convert column (character position) to byte offset
        line_bytes = extract_line_bytes(line_start)
        line_string = line_bytes.pack("C*").force_encoding(encoding)
        prefix = line_string[0...column] || ""
        byte_offset = prefix.bytesize

        line_start + byte_offset
      end

      # @rbs line_start: Integer
      def extract_line_bytes(line_start) #: Array[Integer]
        line_bytes = [] #: Array[Integer]
        i = line_start
        while i < source_bytes.length && source_bytes[i] != LF
          line_bytes << source_bytes[i] #: Integer
          i += 1
        end
        line_bytes
      end

      # @rbs content: String
      # @rbs position: Integer
      # @rbs location: ::Herb::Location
      def build_result(content, position, location) #: Result
        Result.new(
          position:,
          tag_opening: "",
          tag_closing: "",
          prefix: "",
          content:,
          location:,
          node: nil
        )
      end
    end
  end
end
