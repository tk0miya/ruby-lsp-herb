# frozen_string_literal: true

module RuboCop
  module Herb
    # Class for transforming HTML tags to Ruby code while preserving byte length.
    #
    # Transformation rules:
    #   Opening tag (no attrs): <div>        → " div;"        (6 bytes)
    #   Opening tag (attrs):    <div id="x"> → ' div id=""; ' (12 bytes)
    #   Closing tag:            </div>       → " div1;"       (7 bytes, counter rotates 1-9,0)
    #
    # Attribute format is preserved: id="value" becomes id="", making it easier
    # to identify original HTML attributes in RuboCop error messages.
    # The quote character used is based on RuboCop's Style/StringLiterals config.
    #
    # For multibyte characters, padding with spaces is used to preserve byte length.
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
                    transformed_attrs = transform_attrs(attrs.to_s)
                    if transformed_attrs.start_with?(";")
                      # All keyword attrs: put semicolon right after tag name to avoid SpaceBeforeSemicolon
                      # <i class="x"> → " i;            " (semicolon after tag name, rest are spaces)
                      " #{tag_name};#{space}#{transformed_attrs[1..]} "
                    else
                      # Has non-keyword attrs: keep semicolon in attrs
                      # <div id="x"> → " div id=""; " (semicolon after empty quotes)
                      " #{tag_name}#{space}#{transformed_attrs} "
                    end
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

      # Transforms quoted attributes: id="value" → id="";
      # - Attribute name and = are preserved (unless name is a Ruby keyword)
      # - Value is removed, quotes become empty ("")
      # - Semicolon and padding spaces are added to maintain byte count
      # - Ruby keywords (class, for, etc.) are replaced with spaces
      # - Semicolon is placed to avoid Layout/SpaceBeforeSemicolon violations
      # Example: id="x" → id=""; (6 bytes both)
      # Example: class="admin" → ;(12 spaces) (13 bytes both)
      # Example: id="x" class="admin" → id="";(14 spaces) (20 bytes both)
      # @rbs attrs: String
      def transform_quoted_attrs(attrs) #: String
        quote = preferred_quote
        bytes_saved = 0
        has_non_keyword_attr = false

        # Match attribute names including Unicode letters (e.g., 属性="value")
        result = attrs.gsub(/([\p{L}_][\p{L}\p{N}_-]*)=["']([^"']*)["']/) do |match|
          name = ::Regexp.last_match(1).to_s
          value = ::Regexp.last_match(2).to_s
          if ruby_keyword?(name)
            # Ruby keyword: replace entire attribute with spaces
            " " * match.bytesize
          else
            bytes_saved += value.bytesize
            has_non_keyword_attr = true
            "#{name}=#{quote}#{quote}"
          end
        end

        # Add semicolon and pad with spaces to match original byte count
        # Place semicolon to avoid Layout/SpaceBeforeSemicolon
        if has_non_keyword_attr
          # Put semicolon right after the last empty quotes, then spaces
          with_semicolon = result.sub(/#{Regexp.escape(quote)}(?=[^#{Regexp.escape(quote)}]*\z)/, "#{quote};")
          "#{with_semicolon}#{" " * (bytes_saved - 1)}"
        else
          # All attributes were keywords, put semicolon at the start
          ";#{result[1...]}"
        end
      end

      RUBY_KEYWORDS = %w[
        BEGIN END alias and begin break case class def defined? do else elsif end
        ensure false for if in module next nil not or redo rescue retry return self
        super then true undef unless until when while yield __ENCODING__ __FILE__ __LINE__
      ].to_set.freeze #: Set[String]
      private_constant :RUBY_KEYWORDS

      # @rbs name: String
      def ruby_keyword?(name) #: bool
        RUBY_KEYWORDS.include?(name)
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
