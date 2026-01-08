# frozen_string_literal: true

require "digest"

module RuboCop
  module Herb
    # Class for transforming HTML tags to Ruby code while preserving byte length.
    #
    # Transformation rules:
    #   Opening tag (no attrs): <div>        → "div; "        (5 bytes)
    #   Opening tag (attrs):    <div id="x"> → 'div "d= x"; ' (12 bytes)
    #   Closing tag:            </div>       → "divX; "       (6 bytes, X is hash-based char)
    #
    # The closing tag character is determined by hashing the opening tag source,
    # so identical opening tags produce identical closing tags.
    #
    # For multibyte characters, padding with spaces is used to preserve byte length:
    #   <div 属性="x"> → 'div "  性= x"; ' (属 is 3 bytes → " + 2 spaces)
    class HtmlTagTransformer
      OPEN_TAG_PATTERN = /\A<([a-zA-Z0-9]+)(\s*)(.*)>\z/m
      CLOSE_TAG_PATTERN = %r{\A</([a-zA-Z0-9]+)>\z}

      # Characters valid for Ruby identifiers (a-z, A-Z, 0-9, _)
      IDENTIFIER_CHARS = (("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a + ["_"]).freeze #: Array[String]

      attr_reader :config #: RuboCop::Config?

      # @rbs config: RuboCop::Config?
      def initialize(config) #: void
        @config = config
      end

      # @rbs source: String
      # @rbs position: Integer
      # @rbs location: untyped
      def transform_open_tag(source, position:, location:) #: Result?
        match = source.match(OPEN_TAG_PATTERN)
        return nil unless match

        tag_name, space, attrs = match.captures
        attrs = transform_attrs(attrs.to_s)

        build_result("#{tag_name}#{space}#{attrs}; ", position, location)
      end

      # @rbs source: String
      # @rbs position: Integer
      # @rbs location: untyped
      # @rbs open_tag_source: String?
      def transform_close_tag(source, position:, location:, open_tag_source:) #: Result?
        suffix = hash_char(open_tag_source)
        content = source.sub(CLOSE_TAG_PATTERN) { "#{::Regexp.last_match(1)}#{suffix}; " }
        return nil if content == source

        build_result(content, position, location)
      end

      private

      # Computes a single character hash from the source string.
      # @rbs source: String?
      def hash_char(source) #: String
        return "0" unless source

        digest = Digest::MD5.hexdigest(source)
        index = digest.to_i(16) % IDENTIFIER_CHARS.size
        IDENTIFIER_CHARS[index]
      end

      # @rbs attrs: String
      def transform_attrs(attrs) #: String
        return " " * attrs.bytesize if attrs.length < 2

        transform_quoted_attrs(attrs)
      end

      # @rbs attrs: String
      def transform_quoted_attrs(attrs) #: String
        attrs.gsub(/["']/, " ").tap do |result|
          result[0] = convert_quote_char(result[0])
          result[-1] = convert_quote_char(result[-1])
        end
      end

      # Converts a character to a quote with padding to preserve byte length.
      # @rbs char: String?
      def convert_quote_char(char) #: String
        return preferred_quote if char.nil?

        padding = " " * [char.bytesize - 1, 0].max
        preferred_quote + padding
      end

      def preferred_quote #: String
        return '"' unless config

        style = config.for_cop("Style/StringLiterals")["EnforcedStyle"]
        style == "single_quotes" ? "'" : '"'
      end

      # @rbs content: String
      # @rbs position: Integer
      # @rbs location: untyped
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
