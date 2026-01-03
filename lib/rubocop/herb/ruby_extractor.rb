# frozen_string_literal: true

require "herb"
require_relative "erb_comment_transformer"

module RuboCop
  module Herb
    # Extractor for extracting Ruby code from ERB templates using Herb parser.
    # This class is registered with RuboCop::Runner.ruby_extractors to enable
    # linting of Ruby code embedded in ERB files.
    class RubyExtractor
      SUPPORTED_EXTENSIONS = %w[.html.erb].freeze #: Array[String]

      # Character codes for byte manipulation
      LF = 10 #: Integer
      CR = 13 #: Integer
      SPACE = 32 #: Integer
      HASH = 35 #: Integer
      SEMICOLON = 59 #: Integer

      attr_reader :processed_source #: RuboCop::ProcessedSource

      class << self
        # @rbs processed_source: RuboCop::ProcessedSource
        def call(processed_source) #: Array[{ offset: Integer, processed_source: RuboCop::ProcessedSource }]?
          new(processed_source).call
        end
      end

      # @rbs processed_source: RuboCop::ProcessedSource
      def initialize(processed_source) #: void
        @processed_source = processed_source
      end

      def call #: rubyExtractorResult
        return nil unless supported_file?

        parse_result = ::Herb.parse(processed_source.raw_source)
        return [] if parse_result.errors.any?

        unified_source = build_unified_ruby_source(parse_result)
        return [] if unified_source.nil?

        [{
          offset: 0,
          processed_source: build_processed_source(unified_source)
        }]
      end

      private

      def supported_file? #: bool
        return false unless processed_source.path

        SUPPORTED_EXTENSIONS.any? do |ext|
          processed_source.path.end_with?(ext)
        end
      end

      # @rbs parse_result: Herb::ParseResult
      def build_unified_ruby_source(parse_result) #: String?
        original_source = processed_source.raw_source
        visitor = ErbNodeVisitor.new
        parse_result.visit(visitor)

        return nil if visitor.erb_nodes.empty?

        build_whitespace_padded_source(original_source, visitor.erb_nodes)
      end

      # @rbs original_source: String
      # @rbs erb_nodes: Array[untyped]
      def build_whitespace_padded_source(original_source, erb_nodes) #: String
        # Initialize with spaces (preserve newlines)
        result_bytes = original_source.bytes.map { |b| [LF, CR].include?(b) ? b : SPACE }

        # Copy Ruby code from ERB nodes
        erb_nodes.each_with_index do |node, idx|
          following_nodes = following_nodes_on_same_line(node, erb_nodes[(idx + 1)..])

          if comment_node?(node)
            insert_comment(node, following_nodes, result_bytes)
          else
            insert_ruby_code(node, following_nodes, result_bytes)
          end
        end

        result_bytes.pack("C*").force_encoding(original_source.encoding)
      end

      # @rbs node: untyped
      # @rbs _following_nodes: Array[untyped]
      # @rbs result_bytes: Array[Integer]
      def insert_ruby_code(node, _following_nodes, result_bytes) #: void
        from = node.content.range.from
        content_bytes = node.content.value.bytes
        result_bytes[from, content_bytes.length] = content_bytes

        result_bytes[semicolon_position(node)] = SEMICOLON
      end

      # @rbs node: untyped
      # @rbs following_nodes: Array[untyped]
      # @rbs result_bytes: Array[Integer]
      def insert_comment(node, following_nodes, result_bytes) #: void
        content = ERBCommentTransformer.call(node, following_nodes)
        return unless content

        tag_start = node.tag_opening.range.from
        result_bytes[tag_start + 2] = HASH

        from = node.content.range.from
        content_bytes = content.bytes
        result_bytes[from, content_bytes.length] = content_bytes
      end

      # @rbs node: untyped
      def comment_node?(node) #: bool
        return false unless node.respond_to?(:tag_opening)

        node.tag_opening.value == "<%#"
      end

      # @rbs node: untyped
      # @rbs candidates: Array[untyped]?
      def following_nodes_on_same_line(node, candidates) #: Array[untyped]
        return [] unless candidates

        end_line = node.location.end.line
        candidates.take_while { |n| n.location.start.line == end_line }
      end

      # @rbs node: untyped
      def semicolon_position(node) #: Integer
        content = node.content.value
        trailing_spaces = content.length - content.rstrip.length
        node.content.range.to - trailing_spaces
      end

      # @rbs code: String
      def build_processed_source(code) #: RuboCop::ProcessedSource
        RuboCop::ProcessedSource.new(
          code,
          @processed_source.ruby_version,
          @processed_source.path,
          parser_engine: @processed_source.parser_engine
        ).tap do |source|
          source.config = @processed_source.config
          source.registry = @processed_source.registry
        end
      end

      # Visitor class to collect ERB nodes from Herb AST
      class ErbNodeVisitor < ::Herb::Visitor
        attr_reader :erb_nodes #: Array[untyped]

        def initialize #: void
          @erb_nodes = []
          super
        end

        # @rbs node: untyped
        def visit_child_nodes(node) #: void
          @erb_nodes << node if erb_node?(node)
          super
        end

        private

        # @rbs node: untyped
        def erb_node?(node) #: bool
          node.node_name.start_with?("ERB")
        end
      end
    end
  end
end
