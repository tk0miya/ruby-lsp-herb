# frozen_string_literal: true

require "set"

module RuboCop
  module Herb
    # Class for transforming HTML tags to Ruby code while preserving byte length.
    #
    # Transformation rules:
    #   Opening tag (no attrs): <div>                  → " div;"                  (6 bytes)
    #   Opening tag (1 attr):   <div id="x">           → ' div id="x" '           (12 bytes)
    #   Opening tag (2+ attrs): <div id="x" data="y">  → ' div id="x" data="y" '  (22 bytes)
    #   Closing tag:            </div>                 → " div1;"                 (7 bytes)
    #
    # Quotes are normalized to RuboCop's preferred style (Style/StringLiterals).
    # Ruby keywords (class, for, etc.) are replaced with spaces to avoid syntax errors.
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

        content = if attrs.to_s.empty?
                    # <div> → " div;" (< becomes space, > becomes ;)
                    " #{tag_name}#{space};"
                  else
                    # <div id="x"> → " div id= x  " (attrs with quotes replaced by spaces)
                    " #{tag_name}#{space}#{transform_attrs(attrs.to_s)} "
                  end
        build_result(content, position, location)
      end

      # @rbs source: String
      # @rbs position: Integer
      # @rbs location: untyped
      def transform_close_tag(source, position:, location:) #: Result?
        # </div> → " div0;" (< becomes space, / removed, > becomes ;)
        content = source.sub(CLOSE_TAG_PATTERN) { " #{::Regexp.last_match(1)}#{next_close_tag_count};" }
        return nil if content == source

        build_result(content, position, location)
      end

      # Ruby reserved keywords that would cause syntax errors if used as identifiers
      RUBY_KEYWORDS = Set.new(
        %w[
          class for if unless while until case when begin end
          def do module rescue ensure raise return yield break next
          and or not in alias defined? super self nil true false
          __FILE__ __LINE__ __ENCODING__
        ]
      ).freeze #: Set[String]

      private

      def next_close_tag_count #: Integer
        @close_tag_counter = (@close_tag_counter + 1) % 10
      end

      # Transforms attributes, preserving format like id="".
      # The result includes ; at the end (replacing the last char).
      # @rbs attrs: String
      def transform_attrs(attrs) #: String
        return ";" if attrs.empty?
        return ";#{" " * (attrs.bytesize - 1)}" if attrs.bytesize == 1
        return "#{" " * (attrs.bytesize - 1)};" unless attrs.match?(/=["']/)

        transform_quoted_attrs(attrs)
      end

      # Transforms quoted attributes by replacing quotes with RuboCop's preferred style.
      # Ruby keywords (class, for, etc.) are replaced entirely with spaces.
      # Example: id="x" → id="x" (quotes normalized to preferred style)
      # Example: class="admin" → (13 spaces) (Ruby keyword)
      # @rbs attrs: String
      def transform_quoted_attrs(attrs) #: String
        attr_pattern = /([a-zA-Z0-9_-]+)=(["'])(.*?)\2/

        attrs.gsub(attr_pattern) do
          match = ::Regexp.last_match
          next "" unless match

          key = match[1].to_s
          full_match = match[0].to_s
          value = full_match[(key.size + 1)..]

          if ruby_keyword?(key)
            " " * full_match.bytesize
          else
            # Replace quotes in value with spaces, then wrap with preferred quote
            inner = value.to_s.gsub(/['"]/, " ")[1..-2]
            "#{key}=#{preferred_quote}#{inner}#{preferred_quote}"
          end
        end
      end

      # @rbs name: String
      def ruby_keyword?(name) #: bool
        RUBY_KEYWORDS.include?(name)
      end

      # Returns the preferred quote character based on RuboCop config
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
