# frozen_string_literal: true

module RuboCop
  module Herb
    # Class for transforming HTML tags to Ruby code while preserving byte length.
    #
    # Transformation rules:
    #   Opening tag (no attrs): <div>        → "div; "        (5 bytes)
    #   Opening tag (attrs):    <div id="x"> → "div 'd=\"x'; " (12 bytes)
    #   Closing tag:            </div>       → "div0; "       (6 bytes, counter rotates 0-9)
    #
    # When attributes contain ="..." or ='...', the first quote after = is preserved
    # and the wrapper quote is selected as the opposite (to avoid escaping).
    # This makes it easier to identify the original HTML attribute format.
    #
    # For multibyte characters, padding with spaces is used to preserve byte length:
    #   <div 属性="x"> → "div '  性=\"x'; " (属 is 3 bytes → ' + 2 spaces)
    class HtmlTagTransformer
      OPEN_TAG_PATTERN = /\A<([a-zA-Z0-9]+)(\s*)(.*)>\z/m
      CLOSE_TAG_PATTERN = %r{\A</([a-zA-Z0-9]+)>\z}

      attr_reader :config #: RuboCop::Config?

      # @rbs @close_tag_counter: Integer

      # @rbs config: RuboCop::Config?
      def initialize(config) #: void
        @config = config
        @close_tag_counter = 0
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
      def transform_close_tag(source, position:, location:) #: Result?
        content = source.sub(CLOSE_TAG_PATTERN) { "#{::Regexp.last_match(1)}#{next_close_tag_count}; " }
        return nil if content == source

        build_result(content, position, location)
      end

      private

      def next_close_tag_count #: Integer
        @close_tag_counter = (@close_tag_counter + 1) % 10
      end

      # @rbs attrs: String
      def transform_attrs(attrs) #: String
        return " " * attrs.bytesize if attrs.length < 2

        transform_quoted_attrs(attrs)
      end

      # @rbs attrs: String
      def transform_quoted_attrs(attrs) #: String
        preserved_quote = find_first_preserved_quote(attrs)
        wrapper_quote = select_wrapper_quote(preserved_quote)
        result = transform_attr_quotes(attrs, preserved_quote)
        result[0] = convert_quote_char(result[0], wrapper_quote)
        result[-1] = convert_quote_char(result[-1], wrapper_quote)
        result
      end

      # Finds the first quote character after = in the attributes.
      # @rbs attrs: String
      def find_first_preserved_quote(attrs) #: String?
        match = attrs.match(/=["']/)
        return nil unless match

        matched = match[0]
        matched ? matched[-1] : nil
      end

      # Selects the wrapper quote character based on the preserved quote.
      # @rbs preserved_quote: String?
      def select_wrapper_quote(preserved_quote) #: String
        if preserved_quote
          preserved_quote == '"' ? "'" : '"'
        else
          preferred_quote
        end
      end

      # Transforms attribute quotes while preserving the first one after =.
      # @rbs attrs: String
      # @rbs preserved_quote: String?
      def transform_attr_quotes(attrs, preserved_quote) #: String
        first_preserved = false
        attrs.gsub(/=["']|["']/) do |match|
          if match.start_with?("=") && !first_preserved && match[-1] == preserved_quote
            first_preserved = true
            match # preserve ="
          elsif match.start_with?("=")
            "= " # replace quote with space
          else
            " " # replace standalone quote with space
          end
        end
      end

      # Converts a character to a quote with padding to preserve byte length.
      # @rbs char: String?
      # @rbs quote: String
      def convert_quote_char(char, quote) #: String
        return quote if char.nil?

        padding = " " * [char.bytesize - 1, 0].max
        quote + padding
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
