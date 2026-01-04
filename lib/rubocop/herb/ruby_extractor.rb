# frozen_string_literal: true

require "herb"
require_relative "block_placeholder"
require_relative "characters"
require_relative "erb_comment_transformer"
require_relative "erb_node_transformer"

module RuboCop
  module Herb
    # Extractor for extracting Ruby code from ERB templates using Herb parser.
    # This class is registered with RuboCop::Runner.ruby_extractors to enable
    # linting of Ruby code embedded in ERB files.
    class RubyExtractor
      include Characters

      SUPPORTED_EXTENSIONS = %w[.html.erb].freeze #: Array[String]

      # @rbs! type result = Array[{ offset: Integer, processed_source: ProcessedSource }]?

      attr_reader :processed_source #: RuboCop::ProcessedSource

      class << self
        # @rbs processed_source: RuboCop::ProcessedSource
        def call(processed_source) #: result
          new(processed_source).call
        end
      end

      # @rbs processed_source: RuboCop::ProcessedSource
      def initialize(processed_source) #: void
        @processed_source = processed_source
      end

      def call #: result
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
      # @rbs erb_nodes: Array[Herb::AST::erb_nodes]
      def build_whitespace_padded_source(original_source, erb_nodes) #: String
        # Initialize with spaces (preserve newlines)
        result_bytes = original_source.bytes.map { |b| [LF, CR].include?(b) ? b : SPACE }

        # Copy Ruby code from ERB nodes
        erb_nodes.each_with_index do |node, idx|
          following_nodes = erb_nodes[(idx + 1)..] || []

          if comment_node?(node)
            insert_comment(node, following_nodes, result_bytes)
          elsif node.is_a?(::Herb::AST::ERBBlockNode)
            insert_block_code(node, following_nodes, result_bytes)
          else
            insert_ruby_code(node, following_nodes, result_bytes)
          end
        end

        result_bytes.pack("C*").force_encoding(original_source.encoding)
      end

      # @rbs node: ::Herb::AST::ERBBlockNode
      # @rbs following_nodes: Array[Herb::AST::erb_nodes]
      # @rbs result_bytes: Array[Integer]
      def insert_block_code(node, following_nodes, result_bytes) #: void
        insert_ruby_code(node, [], result_bytes)

        next_node = following_nodes.first
        return unless next_node.is_a?(::Herb::AST::ERBEndNode)

        placeholder = BlockPlaceholder.build(node, next_node, result_bytes)
        result_bytes[placeholder.position, placeholder.content.length] = placeholder.content if placeholder
      end

      # @rbs node: Herb::AST::erb_nodes
      # @rbs following_nodes: Array[Herb::AST::erb_nodes]
      # @rbs result_bytes: Array[Integer]
      def insert_ruby_code(node, following_nodes, result_bytes) #: void
        result = ERBNodeTransformer.call(node, following_nodes)
        content_bytes = result.content.bytes
        result_bytes[result.position, content_bytes.length] = content_bytes
      end

      # @rbs node: Herb::AST::erb_nodes
      # @rbs following_nodes: Array[Herb::AST::erb_nodes]
      # @rbs result_bytes: Array[Integer]
      def insert_comment(node, following_nodes, result_bytes) #: void
        result = ERBCommentTransformer.call(node, following_nodes)
        return unless result

        content_bytes = result.content.bytes
        result_bytes[result.position, content_bytes.length] = content_bytes
      end

      # @rbs node: Herb::AST::erb_nodes
      def comment_node?(node) #: bool
        return false unless node.respond_to?(:tag_opening)

        node.tag_opening.value == "<%#"
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
        attr_reader :erb_nodes #: Array[Herb::AST::erb_nodes]

        def initialize #: void
          @erb_nodes = []
          super
        end

        # @rbs node: Herb::AST::nodes
        def visit_child_nodes(node) #: void
          @erb_nodes << node if erb_node?(node) # steep:ignore
          super
        end

        private

        # @rbs node: Herb::AST::nodes
        def erb_node?(node) #: bool
          node.node_name.start_with?("ERB")
        end
      end
    end
  end
end
