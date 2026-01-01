# frozen_string_literal: true

require "herb"

module RuboCop
  module Herb
    # Extractor for extracting Ruby code from ERB templates using Herb parser.
    # This class is registered with RuboCop::Runner.ruby_extractors to enable
    # linting of Ruby code embedded in ERB files.
    class RubyExtractor
      SUPPORTED_EXTENSIONS = %w[.html.erb].freeze #: Array[String]

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

        visitor = ErbNodeVisitor.new
        parse_result.visit(visitor)

        visitor.erb_nodes.filter_map do |node|
          code = node.content.value
          next if code.strip.empty?

          {
            offset: node.content.range.from,
            processed_source: build_processed_source(code)
          }
        end
      end

      private

      def supported_file? #: bool
        return false unless processed_source.path

        SUPPORTED_EXTENSIONS.any? do |ext|
          processed_source.path.end_with?(ext)
        end
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
          @erb_nodes << node if erb_node?(node) && !comment_node?(node)
          super
        end

        private

        # @rbs node: untyped
        def erb_node?(node) #: bool
          node.node_name.start_with?("ERB")
        end

        # @rbs node: untyped
        def comment_node?(node) #: bool
          return false unless node.respond_to?(:tag_opening)

          node.tag_opening.value == "<%#"
        end
      end
    end
  end
end
