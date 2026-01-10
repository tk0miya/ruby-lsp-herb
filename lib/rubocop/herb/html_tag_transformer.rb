# frozen_string_literal: true

module RuboCop
  module Herb
    # Class for transforming HTML tags to Ruby code while preserving byte length.
    #
    # Transformation rules:
    #   Opening tag (no attrs):    <div>                        → "div; "
    #   Opening tag (single attr): <div id="foo">               → ' div id="fo"; '
    #   Opening tag (multi attrs): <div id="foo" value="bar">   → ' div id="foo  value= ba"; '
    #   Closing tag:               </div>                       → "div0; " (counter rotates 0-9)
    #
    # For attributes with values, the first attribute name is preserved to make
    # RuboCop lint messages more readable and help users identify the original HTML.
    # All subsequent attributes are represented as part of the first attribute's value.
    # The last character is trimmed to make room for the closing quote and semicolon.
    #
    # For multibyte characters, padding with spaces is used to preserve byte length.
    class HtmlTagTransformer
      OPEN_TAG_PATTERN = /\A<([a-zA-Z0-9]+)(\s*)(.*)>\z/m
      CLOSE_TAG_PATTERN = %r{\A</([a-zA-Z0-9]+)>\z}
      VALUED_ATTR_PATTERN = /\A([a-zA-Z0-9]+?=)(.*)/m

      # Ruby keywords that cannot be used as method names/identifiers
      RUBY_KEYWORDS = %w[
        BEGIN END alias and begin break case class def defined? do else elsif
        end ensure false for if in module next nil not or redo rescue retry
        return self super then true undef unless until when while yield
      ].freeze

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

        tag_name, space, attrs_str = match.captures
        content = build_open_tag_content(tag_name.to_s, space.to_s, attrs_str.to_s)
        build_result(content, position, location)
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

      # @rbs tag_name: String
      # @rbs space: String
      # @rbs attrs_str: String
      def build_open_tag_content(tag_name, space, attrs_str) #: String
        if attrs_str.empty? || attrs_str.length < 2
          # No attrs or very short attrs - use old format
          "#{tag_name}#{space}#{" " * attrs_str.bytesize}; "
        elsif (match = attrs_str.match(VALUED_ATTR_PATTERN))
          build_valued_attrs_content(tag_name, space, attrs_str, match[1].to_s, match[2].to_s)
        else
          # Boolean attrs - use old format
          "#{tag_name}#{space}#{transform_boolean_attrs(attrs_str)}; "
        end
      end

      # @rbs tag_name: String
      # @rbs space: String
      # @rbs attrs_str: String
      # @rbs attr_prefix: String
      # @rbs value_part: String
      def build_valued_attrs_content(tag_name, space, attrs_str, attr_prefix, value_part) #: String
        attr_name = attr_prefix.chop # Remove trailing '='
        if RUBY_KEYWORDS.include?(attr_name)
          # Keyword attr name - use old format to avoid syntax errors
          "#{tag_name}#{space}#{transform_keyword_attrs(attrs_str)}; "
        else
          # Valued attrs - leading space, trailing space, attrs trimmed by 1 byte
          " #{tag_name}#{space}#{transform_valued_attrs(attr_prefix, value_part)}; "
        end
      end

      def next_close_tag_count #: Integer
        @close_tag_counter = (@close_tag_counter + 1) % 10
      end

      # Transform attributes when the first attribute has a value (e.g., foo="bar").
      # Preserves the attribute name and converts all subsequent content into the value.
      # Trims the last character to make room for the trailing "; " after attrs.
      # @rbs attr_prefix: String
      # @rbs value_part: String
      def transform_valued_attrs(attr_prefix, value_part) #: String
        # Replace all quotes with spaces in value part
        value = value_part.gsub(/["']/, " ")

        # Set opening quote at start of value
        value[0] = convert_quote_char(value[0])

        # Trim last char and set closing quote (makes room for "; " suffix)
        value = value[0..-2]
        return attr_prefix if value.nil? || value.empty?

        value[-1] = convert_quote_char(value[-1])
        attr_prefix + value
      end

      # Transform attributes when the first attribute is boolean (no value).
      # Uses the original format without trimming (no leading space in result).
      # @rbs attrs: String
      def transform_boolean_attrs(attrs) #: String
        attrs.gsub(/["']/, " ").tap do |result|
          result[0] = convert_quote_char(result[0])
          result[-1] = convert_quote_char(result[-1])
        end
      end

      # Transform attributes when the first attribute name is a Ruby keyword.
      # Uses the original format (replacing first char with quote) to avoid syntax errors.
      # @rbs attrs: String
      def transform_keyword_attrs(attrs) #: String
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
